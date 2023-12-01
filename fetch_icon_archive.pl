use strict;
use warnings;

# fetch icon set from https://www.iconarchive.com/
# input will be a webpage containing a full set
# output will be each icon with PNG + ICO under specified px, if available

# url pattern verified as of 2023-05-15

use LWP::Simple;
use File::Path;
use Getopt::Long;

my @urls;
my $dldir;
my $help;
GetOptions(
	"urls=s{1,}"=>\@urls,
	"dir=s"=>\$dldir,
	"help"=>\$help,
);
if ($help or !@urls or !$dldir) {die <<USAGE;
-----------------------------------------
### download icon set from iconarchive.com

[-u ICON_PACK_URL1 URL2 ...] # one or more icon pack URLs
  - if a pack contains multiple pages, give them separately as this script won't parse for it
[-d LOCAL_DIR] # where the downloaded icon files should be saved
  - a subdir `icondownload` will be created here

# note that only the default download PNG plus ICO will be retrieved (for PNG, mostly would be 512px or the largest available one below it).
-----------------------------------------

USAGE
}


my $server='https://www.iconarchive.com';

my $savedir=File::Spec->catfile($dldir, 'icondownload');
foreach my $url (@urls) {
	printf "> %s . . .\n", $url;
	my ($dirname)=$url=~m{show/(.+?)-(icons-)?by-.+?html};
	my $odir=File::Spec->catdir($savedir, $dirname);
	mkpath $odir if !-d $odir;
	if (my $tmp1=get($url)) {
		if ($tmp1=~/class=iconlist\W/) { # only one <div class=iconlist style=text-align:center>
			my $raw=$';
			while ($raw=~m{<div id=.+?class=icondetail>(.+?)</div>}g) { # format tested working as of 2023-05-15
				my $icon1=$1;
				if (my ($iconpage)=$icon1=~m{<a href=(.+?)>}) {
					my $link=$server.$iconpage;
					# e.g. https://www.iconarchive.com/download/i110477/iconarchive/gift/Blue-2-Gift.ico
					# have to retrieve html to get download link
					if (my $tmp2=get($link)) {
						my ($icolink)=$tmp2=~m{<a class=downbutton href=(http\S+) title=};
						if ($icolink=~/\.\d+\.png/) { # normally, this is the default download, which should be 512px or available max, e.g. 256. will update this to ico url
							my $tmp3=$`;
							my $icolink2=$tmp3.'.ico';
							# save files
							my @tmp4=split '\/', $icolink;
							my $fname=$tmp4[-1];
							my @tmp5=split /\./, $fname;
							my $file=File::Spec->catfile($odir, $fname);
							my $file2=File::Spec->catfile($odir, $tmp5[0].'.ico');
							# print ($icolink,"\n", $icolink2);exit;
							if (getstore($icolink, $file)) {
								printf "  %s", $fname;
							}
							if (getstore($icolink2, $file2)) {
								print " + ico";
							}
							print "\n";
						}
					}
				}
			}
		}
	} else {
		print "  couldn't access URL\n";
	}
}

printf "\n\nall done, downloaded files are saved under %s\\\n", $savedir;