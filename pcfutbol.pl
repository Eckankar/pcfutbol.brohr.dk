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
    my $filename = "$tempdir/image" . ($ext ? $ext : "jpg");
    $upload->move_to($filename);

    my $palette = Image::Magick->new;
    $palette->Read('./palette.bmp');

    my $image = Image::Magick->new;
    $image->Read($filename);

    $image->Set(alpha => 'Remove');

    my $bmp_filename_0 = "$filename.0.bmp";
    $image->Write("BMP2:$bmp_filename_0");

    $image = Image::Magick->new;
    $image->Read($bmp_filename_0);
    $image->Resize(geometry => '32x32');

    my $bmp_filename_1 = "$filename.1.bmp";
    $image->Write($bmp_filename_1);

    $image = Image::Magick->new;
    $image->Read($bmp_filename_1);
    $image->Shave(geometry => '1x1');
    $image->Border(geometry => '1x1', bordercolor => 'Black');
    $image->Set(type => 'Palette');
    $image->Set(compression => 'None');
    $image->Remap(image => $palette);

    my $bmp_filename = "$filename.bmp";
    $image->Write("BMP2:$bmp_filename");

    my $fixed_bmp_filename = "$tempdir/output.bmp";

    my $imagedata = capturex(
        '/home/sebbe/build/pcx-utils/bin/pcx-colourpalette',
        qq{bmp=$bmp_filename},
    );

    my $data_url = 'data:image/bmp;base64,' . b64_encode($imagedata);

    $self->stash(
        image_url     => $data_url,
    );

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
