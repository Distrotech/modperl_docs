#!perl

use Image::Magick;

my $image = Image::Magick->new;

$image->Read('banner1.png', 'banner2.png', 'banner3.png', 'mp_banner.png');
$image->Set(iterations => 99);
$image->Write('banner_animated.gif');

# generate thumbnail
$image->Resize(width => 200, height=> 26);
$image->Write('thumbnails/banner_animated.gif');
