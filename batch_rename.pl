#!/usr/bin/perl
use strict;
use warnings;

use Image::ExifTool; # from CPAN
use File::Spec;
use File::Copy qw/move/;
use Getopt::Long;
use Data::Dumper;

### batch rename items in a given folder
my ($dir, $opt_prefix,$opt_suffix, $opt_old, $opt_new, $opt_preview, $opt_dirmode, $opt_lower, $opt_upper, $opt_ext, $opt_exif, $opt_auto, $help);

GetOptions(
	"help"=>\$help,
	"dir=s{1}"=>\$dir,
	"prefix=s{1}"=>\$opt_prefix,
	"suffix=s{1}"=>\$opt_suffix,
	"old=s{1}"=>\$opt_old,
	"new=s{1}"=>\$opt_new,
	"v|preview"=>\$opt_preview,
	"r"=>\$opt_dirmode,
	"lower"=>\$opt_lower,
	"upper"=>\$opt_upper,
	"extension=s{1}"=>\$opt_ext,
	"exif"=>\$opt_exif,
	"auto"=>\$opt_auto,
);

if (!$dir or !-d $dir or $help) {die <<USAGE;
-----------------------------------------

>>> batch rename file/dir <<<
** if after renaming, the new filename overlap with existing filename, rename will be skipped.
** strings for replacing are case insensitive, but if replacing a text string, the new string will be as how you write provide here.

## required
[-d] input dir. everything to be renamed should be under this path, subdirs aren't read

[-v] preview, nothing is renamed


## file filtering
[-ext] process files with this extension, e.g. "-ext jpg"
[-r] process directory names. useful if many folders to be renamed.

## rename file name
[-prefix] add prefix
[-suffix] add suffix
# it's recommended to NOT use space in string replacing
[-old] old pattern, use together with [-new]
[-new] new pattern, use together with [-old]; if [-old] is given but [-new] has nothing, will remove the [-old] string

## case conversion. use either of them
[-l] lower case only
[-u] upper case only

[-exif] extract EXIF info from jpg/jpeg files and rename to timestamp. THIS OVERWRITES ALL OTHER CONFIGS EXCEPT [-auto] below

[-auto] clean format for windows batch named files, e.g. "file (1)" to "file_1". THIS OVERWRITES ALL OTHER CONFIGS.

-----------------------------------------

USAGE
}


if ($opt_ext) {
	$opt_ext=~s/\.//; # remove dot from bad formatting, e.g. ".jpg" to "jpg"
}
my $flist={};
opendir (my $dh, $dir);
while (my $file=readdir ($dh)) { # store all files to array so won't come to the same file if being renamed
	next if $file=~/^\.+$/;
	
	my $infile=File::Spec->catfile($dir, $file);
	if ($opt_dirmode) {
		next if !-d $infile;
	}
	
	if ($opt_auto) {
		if ($file=~/\s\(  (\d+)  \)\s*  \. (\w+)/x) { # looking for windows auto rename pattern "xxx (1).ext"
			$flist->{$file}=[$`, $1, $2]; # do not make new name now. need to see how many files total
		}
	} elsif ($opt_exif) { # jpg, jpeg
		if ($file=~/\.(jpg|jpeg)/i) {
			my $exif=new Image::ExifTool;
			$exif->ExtractInfo($infile);
			my $date=$exif->GetValue('CreateDate');
			if ($date) { # only include this jpg if EXIF info exists
				my (@info)=split /:|\s+/, $date;
				$info[0]=~s/^(20|19)//; # 2 digit year format
				my $file2=sprintf "%s%s%s_%s%s%s", $info[0],$info[1],$info[2],$info[3],$info[4],$info[5];
				$flist->{$file}=[$file2,'jpg'];
			}
		}
	} else {
		# selected extension or any file
		if (($opt_ext and $file=~/\.$opt_ext/i) or !$opt_ext) {
			my $e0='';
			my $f0=$file;
			if ($file=~/\.(\w+)$/) {
				$e0=$1;
				$f0=$`;
			}
			$flist->{$file}=[ $f0, $e0 ];
		}
	}
}
closedir ($dh);
# die Dumper $flist;
print "\n\n";
my $maxnum=length(scalar keys %$flist);
# die $opt_old;
foreach my $file (sort keys %{$flist}) {
	if ($opt_auto) {
		$flist->{$file}=[ (sprintf "%s_%0*d", $flist->{$file}[0], $maxnum, $flist->{$file}[1]), $flist->{$file}[2] ];
	}

	# if non-EXIF mode, see if need to replace string
	if (!$opt_exif and $opt_old) { # all files if old string given
		if ($file=~/$opt_old/i) {
			$opt_new='' if !$opt_new;
			$flist->{$file}[0]=~s/$opt_old/$opt_new/ig;
		}
	}
	# finally, add prefix/suffix
	if ($opt_prefix) {
		$flist->{$file}[0]=$opt_prefix.$flist->{$file}[0];
	}
	if ($opt_suffix) {
		$flist->{$file}[0].=$opt_suffix;
	}

	my $newfile=sprintf "%s.%s", $flist->{$file}[0], $flist->{$file}[1];
	if ($opt_lower) {
		$newfile=lc $newfile;
	}
	elsif ($opt_upper) {
		$newfile=uc $newfile;
	}
	
	if ($file eq $newfile) { # undef, no rename needed
		printf "%s => NO CHANGE\n", $file;
		next;
	} else {
		printf "%s => %s\n", $file, $newfile;
	}

	next if $opt_preview;
	
	my $full1=File::Spec->catfile($dir,$file);
	my $full2=File::Spec->catfile($dir,$newfile);
	if (-e $full2) {
		print "  file under the same name exists, no change!\n";
		next;
	} else {
		move($full1, $full2);
	}
}

if ($opt_preview) {
	print "\n!!!this is preview only, remove flag [-p] to actually rename files.\n";
}

print "\n\nif no output is printed, there are no files to be renamed\n";



=pod
#!/usr/bin/perl
use strict;
use warnings;

use File::Spec;
use File::Copy qw/move/;
use Getopt::Long;
use Data::Dumper;

### batch rename items in a given folder
my ($option,$dir,$ext,$key,$help,$preview,$dirmode,$case);
GetOptions(
	"help"=>\$help,
	"old=s"=>\$key->{key1},
	"new=s"=>\$key->{key2},
	"xtension=s"=>\$ext,
	"formatnumber"=>\$option->{numbers},
	"timestamp"=>\$option->{timestamp},
	"preview"=>\$preview,
	"dir=s{1}"=>\$dir,
	"r"=>\$dirmode,
	"uc"=>\$case->{all_uc},
	"lc"=>\$case->{all_lc},
);
if (!$key->{key2}) {
	$key->{key2}='' if length ($key->{key2})==0;
}

if (!$dir or (!$option and !$key and !$case) or $help) {die <<USAGE;
-----------------------------------------
>>> batch rename files/dirs <<<

[-d READ_DIR] #can NOT deal with subdirs!
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

opendir (my $dh, $dir);

if ($ext) {
	$ext=~s/\.//; # remove dot from bad formatting, e.g. ".jpg" to "jpg"
}
my $flist={};
while (my $file=readdir ($dh)) { # store all files to array so won't come to the same file if being renamed
	next if $file=~/^\.+$/;
	
	my $infile=File::Spec->catfile($dir, $file);
	if ($opt_dirmode) {
		next if !-d $infile;
	}
	
	if ($opt_auto) {
		if ($file=~/\s\(\d+\)/) { # looking for windows auto rename pattern "xxx (1)"
			$flist->{$file}=[$`, $1, $']; # do not make new name now. need to see how many files total
		}
	} elsif ($opt_exif) { # jpg, jpeg
		if ($file=~/\.(jpg|jpeg)/i) {
			$flist->{$file}=1;
		}
	} else {
		if ($opt_ext) { # selected extension
			if ($file=~/\.$opt_ext/i) {
				$flist->{$file}=1;
			}
		} else { # all file
				$flist->{$file}=1;
		}

		# see if need to replace string
		if ($opt_old) { # all files if old string given
			if ($file=~/$opt_old/i) {
				$opt_new='' if !$opt_new;
				my $file2=$file=~s/$opt_old/$opt_new/ig;
				$flist->{$file}=$file2;
			}
		}
	}
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

print "\n!!!this is preview only, remove flag [-p] to actually rename files.\n" if $preview;