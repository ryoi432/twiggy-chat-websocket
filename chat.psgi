#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;

use Pod::Usage;

use Twiggy;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Text::MicroTemplate::File;
use Path::Class qw/file dir/;
use JSON;
use Plack::Request;
use Plack::Builder;
use Plack::App::WebSocket;

my $mtf = Text::MicroTemplate::File->new(
	include_path => ["templates"],
);

my(@clients, %rooms);

my $websocket_app = Plack::App::WebSocket->new(
	on_error => sub {
		my $env = shift;
		return [500,
			["Content-Type" => "text/plain"],
			["Error: " . $env->{"plack.app.websocket.error"}]];
	},
	on_establish => sub {
		my $conn = shift; ## Plack::App::WebSocket::Connection object
		my $env = shift;  ## PSGI env
		my $req = Plack::Request->new($env);
		my $room = ($req->path =~ m!^/(.+)!)[0];
		push(@{$rooms{ $room }}, $conn);
		$conn->on(
			message => sub {
				my ($conn, $json) = @_;

				$json =~ s/^\0//;

				my $data = JSON::decode_json($json);
				$data->{address} = $req->address;
				$data->{time} = time;

				my $msg = JSON::encode_json($data);

				# broadcast
				for my $c (grep { defined } @{ $rooms{$room} || [] }) {
					$c->send($msg);
				}
			},
			finish => sub {
				undef $conn;
			},
		);
	}
);

my $app = sub {
	my $env = shift;
	my $req = Plack::Request->new($env);
	my $res = $req->new_response(200);

	if ($req->path eq '/') {
		$res->content_type('text/html; charset=utf-8');
		$res->content($mtf->render_file('index.mt'));
	} elsif ($req->path =~ m!^/chat!) {
		my $room = ($req->path =~ m!^/chat/(.+)!)[0];
		my $host = $req->header('Host');
		$res->content_type('text/html;charset=utf-8');
		$res->content($mtf->render_file('room.mt', $host, $room));
	} elsif ($req->path =~ m!^/ws!) {
		return $websocket_app->call($env);
	} else {
		$res->code(404);
	}

	$res->finalize;
};

builder {
	enable "Static", path => sub { s!^/static/!! }, root => 'static';
	$app;
};
