#!/bin/perl -w
use MARC::File::USMARC;
use Encode;

# If you have weird control fields...
use MARC::Field;
MARC::Field->allow_controlfield_tags('FMT', 'LDX');    

my $file = MARC::File::USMARC->in( 'file.dat' );

while ( my $record = $file->next() ) {
	## get all of the fields using the fields() method.
	my @fields = $record->fields();
	my $leader = $record->leader();
	print "LDR  ", $leader, "\n";

	## print out the tag, the indicators and the field contents.
	foreach my $field (@fields) {
		my $new_string = encode("utf8", decode("gbk",$field->as_string));
		print
			$field->tag(), " ",
			defined $field->indicator(1) ? $field->indicator(1) : "",
			defined $field->indicator(2) ? $field->indicator(2) : "",
			" ", $new_string, " \n";
			
	}
}
$file->close();
undef $file;
