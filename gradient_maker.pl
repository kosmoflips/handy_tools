#!/usr/bin/perl
use strict;
use warnings;

# by kiyo @ http://www.pocchong.de
# online version: http://www.pocchong.de/e/gradient_maker.cgi
# created: 2016-10-29
# update:
# 20-01-18 master-sub
# 18-11-20 ui update
# 16-10-29 2D gradient
# 15-04-09 html print bug fix
# 15-03-23 alpha support

# inspired by w3school's colour mixer: www.w3schools.com/tags/ref_colormixer.asp
# but is more focusing on my own demands: when I colour/gradient code much text, the <span> tags are ready to use
# and I don't like those online rainbow text generators, they can't either process utf8 , or split all my text to single letters => a big mess

use Data::Dumper;
use Getopt::Long;
use Storable qw/dclone/;

my ($tbx,$tby,$ofile,$opt,$php,$help);
GetOptions(
	'alpha=f{1}'=>\$opt->{alfa},
	'php'=>\$php, # print data for PHP
	'output|ofile=s'=>\$ofile,
	'background=s'=>\$opt->{bg},
	'help'=>\$help,
	'level|lv=i{1}'=>\$opt->{lv},
	'zero=s{1}'=>\$opt->{zero},
	'x=s{1,}'=>\@{$tbx},
	'y=s{1,}'=>\@{$tby},
);

########### TESTING VALS ###########
=pod
$tbx=[qw/  F0f  71f46b  1E90FF /];
$tby=[qw/fbc24f  0c0  fff  8976e6/];
$ofile='D:\kiyoland\my_lipaura\download\gradient.html';
$matrix->{zero}='6bbbf4';
# $opt->{alfa}=0.5;
# $opt->{bg}='ffccff';
$opt->{lv}=25;
=cut
#####################################

if ($help or (!@{$tbx} and !@{$tby})) {
die <<FLAGS;
----------------------------------------
[-z begin_colour] #default=FFF
[-x colour1, 2, 3..n]
[-y colour1, 2, 3..n]
  resulting table looks like:
   [-z]-[x 1,2,..]--[xn]
   |-------------------|
   [y1,----------------|
   [y2,----------------|
   .-------------------|
   .-------------------|
   .-------------------|
   [yn]----------------+

[-lv INT] #mix 2 colours by a step of xxx. default=0 for no gradient, max=254
    #e.g. "5" for placing 5 levels in between -> "start-1-2-3-4-5-end".

[-a alpha] #for text transparency. should >0.00 and <1.00
[-b background] #background colour for html. default=white. does NOT use alpha

[-o] #write to html for preview, use *STDOUT if not specified


NOTE: for input colour codes:
  supported formats (may omit "#" for HEX):
    RGB: R,G,B => e.g. 255,255,255
    HEX: 3-letter shortcut (like in CSS) => e.g. f0a
    HEX: 6-letter regular => e.g. ffeecc
----------------------------------------

FLAGS
}

my $fh; my $zero; my $xx; my $yy;
{ #presets
$fh=verify_fh($ofile);
$opt->{lv}=verify_lv($opt->{lv});
$zero=unify_colour($opt->{zero});
$opt->{bg}=unify_colour($opt->{bg});
$opt->{alfa}=verify_alfa($opt->{alfa});
$xx=verify_clist($tbx);
$yy=verify_clist($tby);
}

#################

my $m2=mix_matrix($zero, $xx, $yy, $opt->{lv});
my $oversize=calc_oversize(scalar @{$xx}, scalar @{$yy}, $opt->{lv});

print_html_head($fh,$opt);
print_matrix_table($m2,$fh);
print_html_end($fh);

print "\n\noutputfile = ".($ofile||'STDOUT')."\n\n";
if ($oversize) {
	print "!warning: the output file will be huge and uses lots of RAM. open with caution!";
}


#################

sub print_matrix_table {
	my ($m2, $fh)=@_;
	$fh=*STDOUT if !$fh;
	print_html_tr($m2->[0],$fh,1); #1 for first row
	foreach my $rl (2..(scalar @$m2)) {#2nd row and following
		my $r=$rl-1;
		print_html_tr($m2->[$r],$fh);
	}
}
sub mix_matrix {
	my ($zero, $xx, $yy, $lv)=@_;
	my $m2;
	{ #1st row, has additional header row for code names
		my $row=mk_row($zero,$zero, $xx, $lv);
		push @$m2, dclone($row);
	}
	{#2nd row and following
		my $row_begin=$zero;
		foreach my $this_y (@$yy) {
			my $step_y=calc_step($row_begin, $this_y, $lv);
			if ($step_y) {
				for my $i (1..$lv) { #loop all mixed b/w y0~y1
					my $labeltxt;
					if ($i==$lv) {
						$row_begin=$this_y;
						$row_begin->[3]=1; #ref mark
						$labeltxt=1;
					} else {
						$row_begin=mix_colour($row_begin,$step_y);
					}
					my $row=mk_row($row_begin, $zero,$xx, $lv);
					push @$m2, dclone($row);
				}
			} else {
				$row_begin=$this_y;
				$row_begin->[3]=1; #ref mark
				my $row=mk_row($row_begin, $zero,$xx, $opt->{lv});
				push @$m2, dclone($row);
			}
		}
	}
	return $m2;
}
sub mk_row {
	my ($begin,$z,$x,$lv)=@_; #A ref, A ref, A ref, INT
	my $row;
	my $last_x=$z;
	my $last_col=$begin;
	push @$row,$begin;
	my $samerow=print_colour_code($z) eq print_colour_code($begin)?1:0;
	foreach my $this_x (@{$x}) {
		if ($lv>1) {
			my $step_x=calc_step($last_x, $this_x, $lv);
			for (1..$lv) {
				my $last_col2=mix_colour($last_col,$step_x);
				push @$row, $last_col2;
				$last_col=$last_col2;
			}
			if ($samerow) {
				$row->[-1]=$this_x;
				$row->[-1][3]=1; #ref mark
			}
		} else {
			$last_col=$this_x;
			$last_col->[3]=1;
			push @$row, $last_col;
		}
		$last_x=$this_x;
	}
	return $row;
}
sub calc_display_colour { #default = #fff, if bg colour all <125, use #fff
	my ($bg)=@_;
	my $low=0;
	for my $i (0..2) {
		$low++ if $bg->[$i]<125;
	}
	if ($low>=2) {
		return 1; #use white txt
	} else {
		return 0; #use dark txt
	}
}
sub invert_colour {
	my ($col)=@_;
	my $c2;
	for my $i (0..2) {
		$c2->[$i]=abs (255-$col->[$i]);
	}
	return $c2;
}
sub unify_colour { # in=string, output=A ref, R,G,B as 0..255
	my ($colour)=@_;
	my $cv;
	my $is_hex;
	if (!$colour) {
		$cv=[255,255,255];
	}
	elsif ($colour=~/(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/) { #treat as RGB
		($cv->[0],$cv->[1],$cv->[2])=($1,$2,$3);
		for my $i (0..2) {
			$cv->[$i]=255 if $cv->[$i]>255;
		}
	}
	elsif ($colour=~/([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i) { #treat as HEX, complete
		($cv->[0],$cv->[1],$cv->[2])=($1,$2,$3);
		$is_hex=1;
	}
	elsif ($colour=~/[0-9a-f]{3}/i) { #treat as HEX, 3-letter
		$is_hex=1;
		my $x0=$&;
		for my $i (0..2) {
			my $xx=substr $x0, $i,1;
			$cv->[$i]=$xx x 2;
		}
	}
	$cv=chk_colour($cv,$is_hex);
	return $cv;
}
sub chk_colour { #in=A ref, out=A ref b/w 0~255
	my ($c2,$is_hex)=@_;
	if (!$c2) {
		$c2=[255,255,255];
	} else {
		for my $i (0..2) {
			if ($is_hex) {
				$c2->[$i]=hex($c2->[$i]);
			}
			if ($c2->[$i]<0) {
				$c2->[$i]=0;
			} elsif ($c2->[$i]>255) {
				$c2->[$i]=255;
			}
		}
	}
	return $c2;
}
sub calc_step { #give 2 colours and lv between, calculate [step]
	my ($c1,$c2,$lv)=@_; #A ref, A ref, INT
	my $dif;
	if ($lv>1) {
		for my $i (0..2) {
			$dif->[$i]=sprintf "%1.2f", (($c2->[$i]-$c1->[$i])/$lv);
		}
	}
	return $dif;
}
sub mix_colour { #give starting colour and step, output new colour
	my ($ori,$step)=@_; #both A ref
	my $c2;
	if ($step) {
		for my $i (0..2) {
			$c2->[$i]=$ori->[$i]+$step->[$i];
		}
		return chk_colour($c2);
	} else {
		return undef;
	}
}
sub calc_oversize {
	my ($xlen, $ylen, $lv, $max)=@_;
	$max=2.5 if !$max;
	my $limit=1024*1024*$max; #MB , limit size of output html page
	my $size_x=$xlen*$lv+$xlen+1;
	my $size_y=$ylen*$lv+$ylen+1;
	my $size=$size_x * $size_y *40; # about 40 byte to show 1 colour <tb>
	if ($size>$limit) {
		return 1;
	} else {
		return 0;
	}
}
sub print_html_head {
my ($fh,$opt)=@_;
print $fh <<HTML;
<!doctype html>
<html>
<head>
<title>Gradient Maker 2D | Pocchong.de</title>
HTML
print_html_head_style($fh);
print $fh <<HTML;
</head>
<body>
HTML
print_html_table_open($opt,$fh);
}
sub print_html_table_open {
	my ($opt,$fh)=@_;
	if ($opt->{bg}) {
		printf $fh '<div style="display: inline-block; padding: 30px; background: %s">%s',print_colour_code($opt->{bg}),"\n";
	} else {
		printf $fh "<div>\n";
	}
	if ($opt->{alfa} and $opt->{alfa}<1) {
		printf $fh '<table style="opacity: %.1f">%s',$opt->{alfa},"\n";
	} else {
		printf $fh "<table>\n";
	}
}
sub print_html_head_style {
	my $fh=shift;
print $fh <<STYLE;
<style>
	body {
		font-family: "Lucida Console", Monaco, monospace;
		text-align:center;
	}
	table {
		border-collapse: collapse;
		border: 1px solid #000;
	}
	td {
		width:20px;
		height:20px;
/*		text-align: center; */
		font-size: 85%%;
	}
	td.rotate {
		padding-top:50px;
		height: 35px;
	}
	td.rotate > div {
		transform: rotate(270deg);
		width: 20px;
	}
	.refcol {
		font-weight:bold;
		text-decoration: underline;
	}
	.hover-toggle .normal-hidden {
		display:none;
		text-align:center;
		padding: 10px;
		border: #fff 1px solid;
	}
	.hover-toggle:hover .normal-hidden {
		display:block;
	}
</style>
STYLE
}
sub print_html_end {
	my $fh=shift;
printf $fh <<HTML;
</table>
</div>
</body>
</html>
HTML
}
sub print_html_tr {
	my ($row,$fh,$firstrow)=@_;
	if ($firstrow) { #need top row for code name;
		printf $fh "<tr>\n";
		printf $fh "<td></td>";
		foreach my $i (0..(@$row-1)) {
			my $cc=$row->[$i];
			if (!ref $cc) {
				printf $fh '<td>%s</td>', ($cc?'x':'');
			} else {
				print_html_td($cc,$fh,-1);
			}
		}
		printf $fh "\n</tr>\n";
	}
	printf $fh "<tr>\n";
	print_html_td($row->[0],$fh,1); #1st cell in the row, display code.
	foreach my $i (1..(@$row-1)) {
		my $cc=$row->[$i];
		if (!ref $cc) {
			printf $fh '<td>%s</td>', ($cc?'x':'');
		} else {
			print_html_td($cc,$fh);
		}
	}
	printf $fh "\n</tr>\n";
	1;
}
sub print_html_td {
	my ($col,$fh,$showcode)=@_; #showcode=0, none; =1, additional <td>. =-1, code only
	$showcode=0 if !$showcode;
	my $invert=calc_display_colour($col);
	my $showcol=sprintf ' style="color:#ffffff;"';
	my $txt=print_colour_code($col);
	if ($showcode and $col->[3]) {
		$txt=sprintf '<span class="refcol">%s</span>', $txt;
	}
	my $sline=sprintf '<td %sstyle="background: %s"><div%s>%s</div></td>',
		($showcode==-1?'class="rotate"':''),
		print_colour_code($col),
		(calc_display_colour($col)?$showcol:''),
		$txt;
	my $cline=sprintf '<td class="hover-toggle" style="background: %s"><span class="normal-hidden"%s>%s<br />%s</span></td>',
		print_colour_code($col),
		($invert?' style="color:#fff"':''),
		print_colour_code($col),
		print_colour_code($col,1);
	if ($showcode==1) {
		printf $fh "%s%s", $sline, $cline;
	}
	elsif ($showcode==-1) {
		printf $fh "%s", $sline;
	} else {
		printf $fh "%s", $cline;
	}
	1;
}
sub print_colour_code {
	my ($col,$rgb,$chkdisplay)=@_;
	my $col2='';
	if ($rgb) {
		$col2=sprintf "rgb(%.0f,%.0f,%.0f)", $col->[0],$col->[1],$col->[2];
	} else {
		$col2=uc (sprintf "#%02x%02x%02x", $col->[0],$col->[1],$col->[2]);
	}
	return $col2;
}
sub verify_fh {
	my $ofile=shift || '';
	if ($ofile!~/\.html/i) {
		$ofile.='.html';
	}
	my $fh;
	eval { open ($fh,">",$ofile); };
	$fh=*STDOUT if !$fh;
	return $fh;
}
sub verify_lv {
	my $lv=shift || "";
	if (!$lv or $lv!~/^\d+$/) {
		$lv=0;
	} elsif ($lv>254) {
		$lv=254;
	}
	$lv++;
	return $lv;
}
sub verify_alfa {
	my $alfa=shift || '';
	if (!$alfa or $alfa!~/^\d\.\d+$/) {
		$alfa=1;
	}
	elsif ($alfa and $alfa<1 and $alfa>0) {
		$alfa=sprintf '%.2f',$alfa;
		$alfa=~s/0+$//g;
		$alfa=~s/\.$//g;
	}
	else {
		$alfa=1;
	}
	return $alfa;
}
sub verify_clist {
	my $cstr=shift || '';
	my $xx;
	my $tbx;
	if (ref($cstr)!~/array/i) {
		@$tbx=split /\s+/, $cstr;
	}
	foreach my $x0 (@{$tbx}) {
		push @$xx, unify_colour($x0);
	}
	return $xx;
}


