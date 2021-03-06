#!/usr/bin/perl 

# http://xml2rfc.ietf.org/public/rfc/bibxml-doi/reference.DOI.$doi.xml
# http://xml2rfc.ietf.org/public/rfc/bibxml-doi/reference.DOI.$doi.kramdown

# http://xml2rfc.ietf.org/public/rfc/bibxml-doi/reference.DOI.10.1145/1355734.1355746.xml

use strict vars;
use CGI qw(taint);

$CGI::DISABLE_UPLOADS = 1;          # Disable uploads
$CGI::POST_MAX        = 512 * 1024; # limit posts to 512K max

my $cgi = CGI->new();

# for testing
# $cgi->param("anchor", "test");  
my $ignoreCache = undef;

my $replacementAnchor = mungeAnchor($cgi->param("anchor"));

my @refs = ();
my $nph = $0 =~ m(/nph-index.cgi);

# print STDERR "0=$0, nph=$nph\n";
if ($#ARGV >= 0) {
    # look at $ARGV for testing purposes to determine format (xml vs kramdown) and references
    @refs = @ARGV;
    # print "ARGV=" . join("|", @ARGV) . "\n";
} else {
    # if no $ARGV, look at $PATH_INFO to determine format (xml vs kramdown) and reference
    @refs = $ENV{PATH_INFO};
}

# for each reference:
for my $ref (@refs) {
    #    if cache has file already and < 24 hours old
    #        cat cached copy
    #    else
    #        grab dx.doi.org/$ref
    #        convert to appropriate format
    #        save in cache
    # print STDERR "ref=$ref\n";
    if ($ref =~ m(^/?reference.DOI[.](\d+[.][^/_]+)[/_]([^/]+)[.](xml|kramdown)$)) {
	my $DOIpt1 = $1;
	my $DOIpt2 = $2;
	my $refnumber = "${DOIpt1}_${DOIpt2}";
	my $type = $3;
	# print STDERR "DOIpt1=$DOIpt1 DOIpt2=$DOIpt2 type=$3\n";
	my $opt = $type eq 'xml' ? "x" : "h";
	# my $CACHEDIR = "/var/tmp/doi-cache";
	my $CACHEDIR = "/var/cache/bibxml-doi";

	my $TMP = "$CACHEDIR/reference.DOI_${refnumber}.${type}";
	# print STDERR "-s $TMP=" . (-s $TMP) . ", -M $TMP=" . (-M _);
	my $printed = undef;
	if ((-s $TMP) && (-M _ < 1) && !$ignoreCache) {
	    print STDERR "Using cached file $TMP\n";
	    if (!open(TMP, "<", $TMP)) {
		print STDERR "Cannot read $TMP: $!\n";
	    } else {
		local $/ = undef;
		my $ret = <TMP>;
		close TMP;
		$ret = replaceAnchor($ret, $type, $replacementAnchor);
		print "HTTP/1.0 200 OK\n" if $nph;
		print "Content-Type: text/$type\n\n";
		print $ret;
		$printed = 1
	    }
	}

	if (!$printed) {
	    umask(0);
	    if ((!-d $CACHEDIR) && !mkdir($CACHEDIR)) {
		print STDERR "Cannot create $CACHEDIR: $!\n";
	    }

	    print STDERR "Running: doilit -$opt=DOI_${refnumber} ${DOIpt1}/${DOIpt2}";
	    my $ref = `doilit -$opt=DOI_${refnumber} ${DOIpt1}/${DOIpt2} | tee "$TMP.tmp";mv "$TMP.tmp" "$TMP"`;
	    if ($ref eq '') {
		printNotFound();
	    } else {
		$ref = replaceAnchor($ref, $type, $replacementAnchor);
		print "HTTP/1.0 200 OK\n" if $nph;
		print "Content-Type: text/$type\n\n";
		print $ref;
	    }
	}
    } else {
	printNotFound();
    }
}

sub mungeAnchor {
    my $anchor = shift;
    $anchor =~ tr/a-z/A-Z/;
    $anchor =~ s/[^A-Z0-9_-]//g;
    return $anchor;
}

sub replaceAnchor {
    my ($ref, $type, $replacementAnchor) = @_;
    if ($replacementAnchor ne "") {
	if ($type eq 'xml') {
	    $ref =~ s/anchor='[^']*'/anchor='$replacementAnchor'/;
	    $ref =~ s/anchor="[^"]*"/anchor='$replacementAnchor'/;
	} else {
	    $ref =~ s/^  [^:]*:/  $replacementAnchor:/;
	}
    }
    return $ref;    
}

sub printNotFound {
    print "HTTP/1.0 404 NOT FOUND\n" if $nph;
    print "Content-type: text/plain\n\n";
    print "invalid DOI or type\n";
}
