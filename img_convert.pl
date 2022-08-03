#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use File::Copy qw/move/;
use Getopt::Long;
use Data::Dumper;

### batch convert png to jpg in a given folder
### by kiyo @ http://www.pocchong.de
### created: 2016-12-28
### updated: 2016-12-28
## 18-11-10: ImageMagick-7.0.8-Q16 x64. changed prog path
## 18-11-12: add flag to convert to ico
# 20-aug 7: icon dimensions

# REQUIRE imagemagick being in system path or use flag [-p]!

my $progpath;
my (@dirs,$help,$protect, @icopx);
GetOptions(
	"help"=>\$help,
	"ico=s{0,}"=>\@icopx,
	"v"=>\$protect,
	"dir=s{1,}"=>\@dirs,
	"prog=s"=>\$progpath,
);

if (!$progpath) {
	# $progpath='D:\Program Files\ImageMagick-7.0.7-Q16\convert.exe';
	$progpath='C:\Program Files\ImageMagick-7.0.9-Q16\magick.exe';
}
if (!-e $progpath) {
	die "can't locate magick.exe!"
}

# my $prog=File::Spec->catfile($progpath,'magick.exe');
# if (!-e $progpath) {
	# printf "the specified 'convert' path doesn't exist. redefine by \"-p\" and retry\n\n";
	# exit;
# }


if (!@dirs or $help) {die <<USAGE;
-----------------------------------------
png/tif/tiff/jpg/jpeg to jpg or ico
[-d READ_DIRs]
[-i] #convert images to ico
   may use "-i 256 128 96 ... " to specify multiple icon dimension
[-p PATH_to_magick.exe]

[-v] protect existing files and quit if files under the same name
by default, existing file under the same name after converted image will be replaced
-----------------------------------------

USAGE
}


foreach my $dir (@dirs) {
	next if !-d $dir;
	printf "\n>>>%s\n", $dir;
opendir (my $dh, $dir);
my $toformat=(@icopx?"ico":"jpg");
my $suffix='(png|tif|tiff|bmp|jpg|jpeg)';
while (my $file=readdir ($dh)) {
	if ($file!~/\. $suffix $/xi) { next; }
	if (!@icopx and $file=~/\. (jpg|jpeg) $/ix) {
		# skip jpg files when not converting to ico
		next;
	}
	printf "%s => %s\n", $file, $toformat;
	my $f1=File::Spec->catfile($dir, $file);
	$f1=~s/"/\\"/g; #in case double quote in file path,escape
	my $f2=$f1;
	$f2=~s/\. $suffix $/./xi;
	$f2 .= $toformat;
	if ($protect and -e $f2) {
		print STDERR "  file exists, exit . . .\n";
		exit;
	}
	my $cmd=sprintf '"%s" "%s"', $f1, $f2;
	if (@icopx) {
		#  http://www.imagemagick.org/Usage/thumbnails/#favicon
		my @px2;
		foreach my $px (@icopx) {
			next if !$px;
			next if $px !~/^\d+$/;
			next if $px>256;
			next if $px<16;
			next if $px%16!=0;
			push @px2, $px;
		}
		if (@px2) {
			$cmd=sprintf '"%s" -define icon:auto-resize="%s" "%s"', $f1, (join ",", @px2),$f2;
		}
	}

	system ($progpath,'convert',$cmd);
}
}
