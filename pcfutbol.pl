#!/usr/bin/env perl
use Mojolicious::Lite;

use File::Temp;
use Image::Magick;
use IPC::System::Simple qw(capturex);
use Mojo::Util qw(b64_encode);

get '/' => sub { shift->render(template => 'index'); };

get '/image' => sub { shift->render(template => 'image'); };

post '/image' => sub {
    my $self = shift;

    return $self->render(text => 'File is too big.', status => 200)
        if $self->req->is_limit_exceeded;

    my $upload = $self->param('image');

    my $tempdir = File::Temp->newdir(TEMPLATE => '/tmp/pcfutbolXXXXXXX');

    my ($ext) = $upload->filename =~ m/\.(\w+)/;
    my $filename = "$tempdir/image." . ($ext ? $ext : "jpg");
    $upload->move_to($filename);

    my @image_urls;

    if ($self->param('image_type') eq 'player') {
        my $imagedata = capturex('./scripts/convert-player', qq{$filename});
        push(@image_urls, 'data:image/bmp;base64,' . b64_encode($imagedata));
    } elsif ($self->param('image_type') eq 'team') {
        my $imagedata = capturex('./scripts/convert-team-logo-mini', qq{$filename});
        push(@image_urls, 'data:image/bmp;base64,' . b64_encode($imagedata));

        $imagedata = capturex('./scripts/convert-team-logo-nano', qq{$filename});
        push(@image_urls, 'data:image/bmp;base64,' . b64_encode($imagedata));
    }

    $self->stash(image_urls => \@image_urls);
    $self->render(template => 'image');

};

app->defaults(layout => 'bootstrap');

app->config(hypnotoad => {
    pid => '/var/run/web/pcfutbol.pid',
    listen => [ 'http://127.0.0.1:14502' ],
    workers => 1,
});

app->log( Mojo::Log->new( path => '/srv/pcfutbol.brohr.dk/logs/mojo.log', level => 'info' ) );

app->start;
