#!/bin/perl
# copyright thomas@nchc.org.tw
use strict;
use warnings;
use DBI;
use MARC::File::USMARC;

# define debug or not
my $debug = 0;

# If you have weird control fields...
use MARC::Field;
MARC::Field->allow_controlfield_tags('FMT', 'LDX');    

# file output to new iso2709 format with utf8 charset
my $OUTFILE = "output.mrc";
open(OUT,">$OUTFILE") or die $!;

# Access OpenBiblio Database directly.
my $db_username = "root";
my $db_password = "okok7480";
my $database = "openbiblio";
my $hostname = "127.0.0.1";
my $port = "3306";
my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dbh = DBI->connect($dsn, $db_username, $db_password) || die "Could not connect to database: $DBI::errstr";

# access table biblio
my $sth_biblio = $dbh->prepare('SELECT bibid, call_nmbr1,  call_nmbr2,  call_nmbr3, title, title_remainder, responsibility_stmt, author, topic1, topic2, topic3, topic4 FROM biblio');
$sth_biblio->execute();
while (my @bibrow = $sth_biblio->fetchrow()) {
	# step1. if bibid can be find in biblio_field, read biblio_field table and write to marc
	# step2. if bibid NOT in biblio_field, we read call_nmbr1  call_nmbr2  call_nmbr3 	
        #                                       title title_remainder responsibility_stmt author
        #                                       topic1 topic2 topic3 topic4
	#        and generate to marc file.

	my $bibid = $bibrow[0];
	print "bib".$bibrow[0]."\t" if $debug;
	print "ca1".$bibrow[1]."\t" if $debug;
	print "ca2".$bibrow[2]."\t" if $debug;
	print "ca3".$bibrow[3]."\t" if $debug;
	print "ti".$bibrow[4]."\t" if $debug;
	print "tirem".$bibrow[5]. "\t" if $debug;
	print "responsibility_stmt".$bibrow[6]."\t" if $debug;
	print "author".$bibrow[7]."\t" if $debug;
	print "tit1".$bibrow[8]."\t" if $debug;
	print "tit2".$bibrow[9]."\t" if $debug;
	print "tit3".$bibrow[10]."\t" if $debug;
	print "tit4".$bibrow[11]."\n" if $debug;
	print "\n" if $debug;

	# step0

	my $newrecord = MARC::Record->new();
        my $leader = '00903pam 2200265 a 4500';
	$newrecord->leader($leader);

	# setp 1
	# access table biblio_field
	my $sth_biblio_field = $dbh->prepare("SELECT fieldid, tag, ind1_cd, ind2_cd, subfield_cd, field_data  
                                              FROM biblio_field WHERE bibid=$bibid");
	$sth_biblio_field->execute() or die $sth_biblio_field->errstr;;
	if ($sth_biblio_field->rows > 0){
		print "step1\n" if $debug;
		while (my @results = $sth_biblio_field->fetchrow()) {
			print $results[0]. "\t"  if $debug;
			print $results[1] if $debug;
			print $results[2] if $debug;
			print $results[3] if $debug;
			print $results[4]. "\t" if $debug;
			print $results[5] if $debug;
			print "\n" if $debug;
			my $field      = $results[0];
			my $tag        = sprintf("%03d", $results[1]);
			my $inc1       = $results[2] if ($results[2] ne 'N');
			my $inc2       = $results[3] if ($results[2] ne 'N');
			my $subfield   = $results[4];
			my $field_data = $results[5];
			
			my $marc_field = MARC::Field->new($tag, $inc1, $inc2, $subfield => $field_data);
                        $newrecord->append_fields($marc_field);
		}
		print OUT $newrecord->as_usmarc();
	} else {
		# step 2
		print "step2\n" if $debug;
		my $title_field = MARC::Field->new('100', '1', ' ', a => $bibrow[4]);
		my $author_field = MARC::Field->new('245', '1', '0', a => $bibrow[7]);
		$newrecord->append_fields($title_field, $author_field);
		print OUT $newrecord->as_usmarc();
	}
}

$dbh->disconnect();
