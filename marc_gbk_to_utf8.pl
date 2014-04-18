#!/bin/perl -w
use strict;
use Getopt::Std;
use MARC::File::USMARC;
use Encode;

sub do_help {
  print "Usage: $0 [options]\n";
  print <<EOF;
Options:
    -i	FILE	input file.
    -o  FILE    output file.
    -f  ENCODE  Convert characters from encoding.
    -d          Debug mode.
    -h          Print this summary.
EOF
  exit;
}

my ($INFILE, $OUTFILE, $DEBUG, $encode);
# declare the perl command line flags/options we want to allow

my (%options, $switch);
getopts("hdi:o:f:", \%options);

foreach $switch(sort keys %options){

  print "$switch = $options{$switch}\n" if $options{d};

}

if ($options{d})
{  
  $DEBUG = 1;
}

if ($options{h})
{
  do_help();
}

if ($options{i})
{
  $INFILE = "$options{i}";
} else {
  do_help();
}

if ($options{o})
{
  $OUTFILE = "$options{o}";
} else {
  do_help();
}

if ($options{f})
{  
  $encode = "$options{f}";
} else {
  do_help();
}



# If you have weird control fields...
use MARC::Field;
MARC::Field->allow_controlfield_tags('FMT', 'LDX');    

# file input with GBK ISO2709 format
my $file = MARC::File::USMARC->in( $INFILE );

# file output to new iso2709 format with utf8 charset
open(OUT,">$OUTFILE") or die $!;

while ( my $record = $file->next() ) {
    my @fields = $record->fields();
    my $leader = $record->leader();

    my $newrecord = MARC::Record->new();
    print $leader, "\n" if $DEBUG;
    $newrecord->leader($leader);

    foreach my $field (@fields) {
	if ($field->tag() < 10){
		MARC::Field->is_controlfield_tag($field->tag());
                my $new_data = encode("utf-8", decode("$encode",$field->data()));
		my $new_field = MARC::Field->new($field->tag(), $new_data);
		print $field->tag(), "     ", $new_data, "\n" if $DEBUG;
		$newrecord->add_fields($new_field);
	} else {
		my @subfields = $field->subfields();
		my @newSubfields = ();
		while ( my $subfield = pop( @subfields ) ) {
			my ($code,$data) = @$subfield;
			$data = encode("utf-8", decode("$encode", $data));
			unshift( @newSubfields, $code, $data );
		}

		my $new_field = MARC::Field->new($field->tag(), $field->indicator(1), $field->indicator(2), @newSubfields);
		print $field->tag(), " ", $field->indicator(1)," ", $field->indicator(2), " ", $new_field->as_string(), "\n" if $DEBUG;
		$newrecord->append_fields($new_field);
	}

    }
    print OUT $newrecord->as_usmarc();
}
$file->close();
undef $file;
close(OUT);

