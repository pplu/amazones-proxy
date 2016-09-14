#!/usr/bin/env perl

use v5.10;
use strict;
use warnings;

use Plack::Request;
use Plack::Response;
use Search::Elasticsearch;
use Net::Amazon::Signature::V4;
use HTTP::Request;
use LWP::UserAgent;
use Paws;
use Data::Dumper;
use POSIX qw(strftime);

sub usage {
  say "Usage: ES_CLUSTER=.... plackup $0";
  exit 1;
}

my $es_cluster = $ENV{ES_CLUSTER} or usage;

my ($region) = ($es_cluster =~ m/\.([a-z0-9-]+)\.es\.amazonaws\.com$/);
die "Could not derive the region from the elasticsearch endpoint" if (not defined $region);

my $paws = Paws->new;

my $app = sub {
  my $env = shift;
  my $req = Plack::Request->new($env);
  my $res = Plack::Response->new;

  print Dumper($req);

  my $request = HTTP::Request->new;

  $request->method($req->method);
  my $new_uri = $req->uri->clone;
  $new_uri->scheme('https');
  $new_uri->host($es_cluster);
  $new_uri->port(443);

  $request->uri($new_uri);
  $request->headers($req->headers);
  $request->content($req->content);

  $request->header(Date => strftime( '%Y%m%dT%H%M%SZ', gmtime ));
  $request->header(Host => $es_cluster);

  print Dumper($request);

  my $signer = Net::Amazon::Signature::V4->new(
    $paws->config->credentials->access_key,
    $paws->config->credentials->secret_key,
    $region,
    'es'
  );
  $signer->sign($request);

  my $ua = LWP::UserAgent->new;
  my $response = $ua->request($request);

  print Dumper($response);

  $res->status($response->code);
  $res->content($response->content);
  $res->headers($response->headers);

  return $res->finalize;
};

