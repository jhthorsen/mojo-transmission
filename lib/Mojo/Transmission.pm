package Mojo::Transmission;
use Mojo::Base -base;

use Mojo::JSON;
use Mojo::UserAgent;
use Mojo::Util qw(dumper url_escape);
use constant DEBUG => $ENV{MOJO_TRANSMISSION_DEBUG} || 0;

has default_trackers => sub { [] };
has ua               => sub { Mojo::UserAgent->new; };
has url =>
  sub { Mojo::URL->new($ENV{TRANSMISSION_RPC_URL} || 'http://localhost:9091/transmission/rpc'); };

sub add {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my ($self, $args) = @_;
  my $url = $args->{url} || '';

  if ($args->{xt}) {
    $url = sprintf 'magnet:?xt=%s&dn=%s', map { $_ // '' } @$args{qw(xt dn)};
    $url .= sprintf '&tr=%s', url_escape $_ for @{$args->{tr} || $self->default_trackers};
  }

  unless ($url) {
    $url .= sprintf 'magnet:?xt=urn:btih:%s', $args->{hash} // '';
    $url .= sprintf '&dn=%s', url_escape($args->{dn} // '');
    $url .= sprintf '&tr=%s', url_escape $_ for @{$args->{tr} || $self->default_trackers};
  }

  $self->_post('torrent-add', {filename => "$url"}, $cb);
}

sub session {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;

  return $self->_post('session-get', $_[0], $cb) if ref $_[0] eq 'ARRAY';
  return $self->_post('session-set', $_[0], $cb) if ref $_[0] eq 'HASH';
  return $self->tap($cb, {error => 'Invalid input.'}) if $cb;
  die 'Invalid input.';
}

sub stats {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;

  return $self->_post('session-stats', {}, $cb);
}

sub torrent {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my ($self, $args, $id) = @_;

  if (defined $id) {
    $id = ref $id ? $id : [$id];
  }

  if (ref $args eq 'ARRAY') {
    $args = {fields => $args};
    $args->{ids} = $id if defined $id;
    return $self->_post('torrent-get', $args, $cb);
  }
  elsif (ref $args eq 'HASH') {
    $args->{ids} = $id if defined $id;
    return $self->_post('torrent-set', $args, $cb);
  }
  elsif ($args eq 'purge') {
    return $self->_post('torrent-remove', {ids => $id, 'delete-local-data' => Mojo::JSON->true},
      $cb);
  }

  return $self->_post("torrent-$args", {ids => $id}, $cb);
}

sub _post {
  my ($self, $method, $req, $cb) = @_;

  $req = {arguments => $req, method => $method};

  # non-blocking
  if ($cb) {
    Mojo::IOLoop->delay(
      sub {
        my ($delay) = @_;
        warn '[TRANSMISSION] <<< ', dumper($req), "\n" if DEBUG;
        $self->ua->post($self->url, $self->_headers, json => $req, $delay->begin);
      },
      sub {
        my ($delay, $tx) = @_;
        warn '[TRANSMISSION] >>> ', dumper($tx->res->json || $tx->res->error), "\n" if DEBUG;
        return $self->$cb(_res($tx)) unless ($tx->res->code // 0) == 409;
        $self->{session_id} = $tx->res->headers->header('X-Transmission-Session-Id');
        $self->ua->post($self->url, $self->_headers, json => $req, $delay->begin);
      },
      sub {
        my ($delay, $tx) = @_;
        warn '[TRANSMISSION] >>> ', dumper($tx->res->json || $tx->res->error), "\n" if DEBUG;
        $self->$cb(_res($tx));
      },
    );

    return $self;
  }

  # blocking
  else {
    warn '[TRANSMISSION] <<< ', dumper($req), "\n" if DEBUG;
    my $tx = $self->ua->post($self->url, $self->_headers, json => $req);
    warn '[TRANSMISSION] >>> ', dumper($tx->res->json || $tx->res->error), "\n" if DEBUG;
    return _res($tx) unless ($tx->res->code // 0) == 409;
    $self->{session_id} = $tx->res->headers->header('X-Transmission-Session-Id');
    $tx = $self->ua->post($self->url, $self->_headers, json => $req);
    warn '[TRANSMISSION] >>> ', dumper($tx->res->json || $tx->res->error), "\n" if DEBUG;
    return _res($tx);
  }
}

sub _headers {
  my $self = shift;
  return {'X-Transmission-Session-Id' => $self->{session_id} || ''};
}

sub _res {
  my $res = $_[0]->res->json || {error => $_[0]->res->error};
  $res->{error} ||= $res->{result};
  return $res if !$res->{result} or $res->{result} ne 'success';
  return $res->{arguments};
}

my @TR_STATUS = qw(stopped check_wait check download_wait download seed_wait seed);
sub tr_status { defined $_[0] ? $TR_STATUS[$_[0]] || '' : '' }

1;

=encoding utf8

=head1 NAME

Mojo::Transmission - Client for talking with Transmission BitTorrent daemon

=head1 DESCRIPTION

See also L<https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt>.

=head1 SYNOPSIS

  my $t = Mojo::Transmission->new;
  $t->add(url => "http://releases.ubuntu.com/17.10/ubuntu-17.10.1-desktop-amd64.iso.torrent");

  my $torrents = $t->torrent([]);
  $t->torrent(remove => $torrents[0]->{id}) if @$torrents;

=head1 ATTRIBUTES

=head2 default_trackers

  $array_ref = $self->default_trackers;
  $self = $self->default_trackers([$url, ...]);

=head2 ua

  $ua = $self->ua;

Holds a L<Mojo::UserAgent> used to issue requests to backend.

=head2 url

  $url = $self->url;

L<Mojo::URL> object holding the URL to the transmission daemon.
Default to C<$ENV{TRANSMISSION_RPC_URL}> or
"http://localhost:9091/transmission/rpc".

=head1 METHODS

=head2 add

  $self = $self->add(
            {hash => "...", dn => "Some description", tr => ["trackers"]},
            sub { my ($self, $res) = @_; }
          );

This method can be used to add a torrent. C<tr> defaults to L</default_trackers>.

See also L<https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L356>.

=head2 session

  # session-get
  $self = $self->session([], sub { my ($self, $res) = @_; });

  # session-set
  $self = $self->session(\%attrs, sub { my ($self, $res) = @_; });

Used to get or set Transmission session arguments.

See also L<https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L444>.

=head2 stats

  # session-stats
  $self = $self->stats(sub { my ($self, $res) = @_; });

Used to retrieve Transmission statistics.

See also L<https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L531>.

=head2 torrent

  # torrent-get
  $self = $self->torrent(\@attrs, $id, sub { my ($self, $res) = @_; });

  # torrent-set
  $self = $self->torrent(\%attrs, $id, sub { my ($self, $res) = @_; });

  # torrent-$action
  $self = $self->torrent(remove => $id, sub { my ($self, $res) = @_; });
  $self = $self->torrent(start => $id, sub { my ($self, $res) = @_; });
  $self = $self->torrent(stop => $id, sub { my ($self, $res) = @_; });

  # torrent-remove + delete-local-data
  $self = $self->torrent(purge => $id, sub { my ($self, $res) = @_; });

Used to get or set torrent related attributes or execute an action on a torrent.

See also:

=over 4

=item * Get torrent attributes

L<https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L127>.

=item * Set torrent attributes

L<https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L90>

=item * Torrent actions

L<https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L71>.

=back

=head1 FUNCTIONS

=head2 tr_status

  $str = tr_status $int;

Returns a description for the C<$int> status:

  0 = stopped
  1 = check_wait
  2 = check
  3 = download_wait
  4 = download
  5 = seed_wait
  6 = seed

Returns empty string on invalid input.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut
