# NAME

Mojo::Transmission - Client for talking with Transmission BitTorrent daemon

# DESCRIPTION

[Mojo::Transmission](https://metacpan.org/pod/Mojo::Transmission) is a very lightweight client for exchanging data with
the Transmission BitTorrent daemon using RPC.

The documentation in this module might seem sparse, but that is because the API
is completely transparent regarding the data-structure received from the
[Transmission API](https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt).

# SYNOPSIS

    my $transmission = Mojo::Transmission->new;
    $transmission->add(url => "http://releases.ubuntu.com/17.10/ubuntu-17.10.1-desktop-amd64.iso.torrent");

    my $torrents = $transmission->torrent([]);
    $transmission->torrent(remove => $torrents[0]->{id}) if @$torrents;

# ATTRIBUTES

## default\_trackers

    $array_ref    = $transmission->default_trackers;
    $transmission = $transmission->default_trackers([$url, ...]);

Holds a list of default trackers that can be used by ["add"](#add).

## ua

    $ua           = $transmission->ua;
    $transmission = $transmission->ua(Mojo::UserAgent->new);

Holds a [Mojo::UserAgent](https://metacpan.org/pod/Mojo::UserAgent) used to issue requests to backend.

## url

    $url          = $transmission->url;
    $transmission = $transmission->url(Mojo::URL->new);

[Mojo::URL](https://metacpan.org/pod/Mojo::URL) object holding the URL to the transmission daemon.
Default to the `TRANSMISSION_RPC_URL` environment variable or
"http://localhost:9091/transmission/rpc".

# METHODS

## add

    # Generic call
    $res          = $transmission->add(\%args);
    $transmission = $transmission->add(\%args, sub { my ($transmission, $res) = @_ });

    # magnet:?xt=${xt}&dn=${dn}&tr=${tr}
    $transmission->add({xt => "...", dn => "...", tr => [...]});

    # magnet:?xt=urn:btih:${hash}&dn=${dn}&tr=${tr}
    $transmission->add({hash => "...", dn => "...", tr => [...]});

    # Custom URL or file
    $transmission->add({url => "...", tr => [...]});

This method can be used to add a torrent. `tr` defaults to ["default\_trackers"](#default_trackers).

See also [https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L356](https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L356).

## add\_p

    $promise = $transmission->add_p(\%args);

Same as ["add"](#add), but returns a promise.

## session

    # session-get
    $transmission = $transmission->session([], sub { my ($transmission, $res) = @_; });
    $res          = $transmission->session([]);

    # session-set
    $transmission = $transmission->session(\%attrs, sub { my ($transmission, $res) = @_; });
    $res          = $transmission->session(\%attrs);

Used to get or set Transmission session arguments.

See also [https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L444](https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L444).

## session\_p

    $promise = $transmission->session_p([]);
    $promise = $transmission->session_p(\%args);

Same as ["session"](#session), but returns a promise.

## stats

    # session-stats
    $transmission = $transmission->stats(sub { my ($transmission, $res) = @_; });
    $res          = $transmission->stats;

Used to retrieve Transmission statistics.

## stats\_p

    $promise = $transmission->stats_p;

Same as ["stats"](#stats), but returns a promise.

See also [https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L531](https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L531).

## torrent

    # torrent-get
    $transmission = $transmission->torrent(\@attrs, $id, sub { my ($transmission, $res) = @_; });
    $res          = $transmission->torrent(\@attrs, $id);

    # torrent-set
    $transmission = $transmission->torrent(\%attrs, $id, sub { my ($transmission, $res) = @_; });
    $res          = $transmission->torrent(\%attrs, $id);

    # torrent-$action
    $transmission = $transmission->torrent(remove  => $id, sub { my ($transmission, $res) = @_; });
    $transmission = $transmission->torrent(start   => $id, sub { my ($transmission, $res) = @_; });
    $transmission = $transmission->torrent(stop    => $id, sub { my ($transmission, $res) = @_; });
    $res          = $transmission->torrent($action => $id);

    # torrent-remove + delete-local-data
    $transmission = $transmission->torrent(purge => $id, sub { my ($transmission, $res) = @_; });

Used to get or set torrent related attributes or execute an action on a torrent.

`$id` can either be a scalar or an array-ref, referring to which torrents to
use.

See also:

- Get torrent attributes

    [https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L127](https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L127).

- Set torrent attributes

    [https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L90](https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L90)

- Torrent actions

    [https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L71](https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt#L71).

## torrent\_p

    $promise = $transmission->torrent_p(\@attrs, ...);
    $promise = $transmission->torrent_p(\%attrs, ...);
    $promise = $transmission->torrent_p($action => ...);

Same as ["torrent"](#torrent), but returns a promise.

# FUNCTIONS

## tr\_status

    use Mojo::Transmission "tr_status";
    $str = tr_status $int;

Returns a description for the `$int` status:

    0 = stopped
    1 = check_wait
    2 = check
    3 = download_wait
    4 = download
    5 = seed_wait
    6 = seed

Returns empty string on invalid input.

# COPYRIGHT AND LICENSE

Copyright (C) 2016, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

# AUTHOR

Jan Henning Thorsen - `jhthorsen@cpan.org`
