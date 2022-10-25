#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use File::Copy qw/move/;
use Getopt::Long;
use Data::Dumper;

### batch rename items in a given folder

my ($option,@dirs,$ext,$key,$help,$preview,$dirmode,$case);
GetOptions(
	"help"=>\$help,
	"old=s"=>\$key->{key1},
	"new=s"=>\$key->{key2},
	"xtension=s"=>\$ext,
	"formatnumber"=>\$option->{numbers},
	"timestamp"=>\$option->{timestamp},
	"preview"=>\$preview,
	"dir=s{1,}"=>\@dirs,
	"r"=>\$dirmode,
	"uc"=>\$case->{all_uc},
	"lc"=>\$case->{all_lc},
);
if (!$key->{key2}) {
	$key->{key2}='' if length ($key->{key2})==0;
}

if (!@dirs or (!$option and !$key and !$case) or $help) {die <<USAGE;
-----------------------------------------
>>> batch rename files/dirs <<<

[-d READ_DIR1 DIR2] #if multiple dir paths given, make sure search pattern don't mess up
  # can NOT deal with subdirs!
[-x EXT] #only get files by extension *.EXT
[-r] #rename dirs instead of files
[-p] #preview before and after name change

[-o OLD_PATTERN -n NEW_PATTERN]
  #case INSENSITIVE
  #expected (but didn't test in depth) to support perl-wide REGEX; use "^" when change at begin of line
  #if omit OLD_PATTERN, will append NEW_PATTERN to the end (e.g. for adding new extension)
  #remove OLD_PATTERN if NEW_PATTERN is omitted

[-u] OR [-l] #change case to all UPPER/lower. will do nothing if both are given
[-f] #replace windows auto-numbered files.
  # e.g. file (1) -> file_01
[-t] #rename photo files (jpg/png/gif/bmp/tiff) by time taken if applicable.

flag priority:
[-t] > [-f] > [-o xxx -n yyy]
-----------------------------------------

USAGE
}

foreach my $dir (@dirs) {
printf "\n>>>>%s\n", $dir;
next if !-d $dir;
opendir (my $dh, $dir);
my $exist={};
my $allfiles=[];
my $max=0;
while (my $file=readdir ($dh)) { # store all files to array so won't come to the same file if being renamed
	next if $file=~/^\.+$/;
	if ($file=~/\s\(\d+\)/) { # get max number for file auto named by windows, e.g. file (1)
		$max++;
	}
	push @$allfiles, $file;
}
foreach my $file (@$allfiles) {
	my $ext2;
	if ($option->{timestamp}) { #grab jpg/png/gif/tiff/bmp
		if ($file=~/\.(jpg|jpeg|png|gif|tiff|bmp)$/ix) {
			$ext2=lc ($1);
		} else {
			next;
		}
	}
	if ($ext) {
		next if $file!~/\. $ext $/ix;
	}

	if ($dirmode) { #rename dir
		next if !-d File::Spec->catfile($dir,$file);
	} else {
		next if -d File::Spec->catfile($dir,$file);
	}

	my $file2=$file;
	if ($option->{timestamp}) {
		use Image::ExifTool; # from CPAN

		my $exif=new Image::ExifTool;
		my $file0=File::Spec->catfile($dir,$file);
		$exif->ExtractInfo($file0);
		my $date=$exif->GetValue('CreateDate');
		if ($date) {
			my (@info)=split /:|\s+/, $date;
			$info[0]=~s/^(20|19)//;
			$file2=sprintf "%s%s%s_%s%s%s.%s", $info[0],$info[1],$info[2],$info[3],$info[4],$info[5],($ext2||'jpg');
		}
	}
	elsif ($option->{numbers}) {
		if ($file=~/\s+  \(   (\d+)  \)/x) {
			$key->{key2}=$1;
			if ($max) {
				$file2=sprintf "%s_%0*d%s",$`,length($max),$key->{key2},$';
			} else {
				$file2=sprintf "%s_%02d%s",$`,$key->{key2},$';
			}
		}
	}
	elsif ($key->{key1} or $key->{key2}) {
		if ($key->{key1}) {
			# $key->{key2}='' if !$key->{key2};
			$file2=~s/$key->{key1}/$key->{key2}/xig;
		}
		elsif (!$key->{key1} and ($key->{key2} or length($key->{keys}) >0 )) {
			$file2.=$key->{key2};
		}
	}

	printf "%s => ",$file;
	if ($file2 ne $file) {
		if ($case->{all_uc} and !$case->{all_lc}) {
			$file2=uc $file;
		}
		elsif (!$case->{all_uc} and $case->{all_lc}) {
			$file2=lc $file;
		}

		printf "%s\n",$file2;
		next if $preview;
		$file=File::Spec->catfile($dir,$file);
		$file2=File::Spec->catfile($dir,$file2);
		next if $exist->{$file}; # so it doesn't read the same file after rename
		if (-e $file2 and (lc $file ne lc $file2)) {
			print "FILE ALREADY EXISTS!"
		} else {
			move ($file,$file2);
			$exist->{$file2}=1;
		}
	} else {
		print "NO CHANGE\n";
	}
}
} #close dirs loop

print "\n!!!this is preview only, remove flag [-p] to actually rename files.\n" if $preview;