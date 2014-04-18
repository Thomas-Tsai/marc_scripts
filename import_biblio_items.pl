#!/usr/bin/perl

# $Id: addbiblio.pl,v 1.52.2.58.2.1 2007/04/27 13:08:28 tipaul Exp $

# Copyright 2000-2002 Katipo Communications
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

use strict;
use CGI;
use C4::Auth;
use C4::Output;
use C4::Interface::CGI::Output;
use C4::Biblio;
use C4::Search;
use C4::SearchMarc; # also includes Biblio.pm, SearchMarc is used to FindDuplicate
use C4::Context;
use C4::Koha; # XXX subfield_is_koha_internal_p
#use Smart::Comments;
use MARC::File::USMARC;
use MARC::File::XML;
if (C4::Context->preference('marcflavour') eq 'UNIMARC') {
	MARC::File::XML->default_record_format( 'UNIMARC' );
}
use vars qw( $authorised_values_sth);
use vars qw( $is_a_modif);

my $itemtype; # created here because it can be used in build_authorized_values_list sub

=item MARCfindbreeding

    $record = MARCfindbreeding($dbh, $breedingid);

Look up the breeding farm with database handle $dbh, for the
record with id $breedingid.  If found, returns the decoded
MARC::Record; otherwise, -1 is returned (FIXME).
Returns as second parameter the character encoding.

=cut

sub MARCfindbreeding {
	my ($dbh,$id) = @_;
	my $sth = $dbh->prepare("select file,marc,encoding from marc_breeding where id=?");
	$sth->execute($id);
	my ($file,$marc,$encoding) = $sth->fetchrow;
	if ($marc) {
		my $record = fixEncoding($marc);

# fix isbn
		my $record = MARC::Record->new_from_usmarc($marc);
		my ($isbnfield,$isbnsubfield) = MARCfind_marc_from_kohafield($dbh,"biblioitems.isbn");
        	if ( $record->field($isbnfield) ) {
            		foreach my $field ( $record->field($isbnfield) ) {
                		foreach my $subfield ( $field->subfield($isbnsubfield) ) {
                    			my $newisbn = $field->subfield($isbnsubfield);
                    			$newisbn =~ s/-//g;
                    			$newisbn = substr($newisbn,0,10);
                    			$field->update( $isbnsubfield => $newisbn );
                		}
            		}
        	}
        
		if (ref($record) eq undef) {
			return -1;
		} else {
			if (C4::Context->preference("z3950NormalizeAuthor") and C4::Context->preference("z3950AuthorAuthFields")){
				my ($tag,$subfield) = MARCfind_marc_from_kohafield($dbh,"biblio.author");
# 				my $summary = C4::Context->preference("z3950authortemplate");
				my $auth_fields = C4::Context->preference("z3950AuthorAuthFields");
				my @auth_fields= split /,/,$auth_fields;
				my $field;
				#warn $record->as_formatted;
				if ($record->field($tag)){
					foreach my $tmpfield ($record->field($tag)->subfields){
#						foreach my $subfieldcode ($tmpfield->subfields){
						my $subfieldcode=shift @$tmpfield;
						my $subfieldvalue=shift @$tmpfield;
						if ($field){
							$field->add_subfields("$subfieldcode"=>$subfieldvalue) if ($subfieldcode ne $subfield);
						} else {
							$field=MARC::Field->new($tag,"","",$subfieldcode=>$subfieldvalue) if ($subfieldcode ne $subfield);
						}
					}
					#warn $field->as_formatted;
#					}
				}
				$record->delete_field($record->field($tag));
				foreach my $fieldtag (@auth_fields){
					next unless ($record->field($fieldtag));
					my $lastname = $record->field($fieldtag)->subfield('a');
					my $firstname= $record->field($fieldtag)->subfield('b');
					my $title = $record->field($fieldtag)->subfield('c');
					my $number= $record->field($fieldtag)->subfield('d');
					if ($title){
# 						$field->add_subfields("$subfield"=>"[ ".ucfirst($title).ucfirst($firstname)." ".$number." ]");
						$field->add_subfields("$subfield"=>ucfirst($title)." ".ucfirst($firstname)." ".$number);
					}else{
# 						$field->add_subfields("$subfield"=>"[ ".ucfirst($firstname).", ".ucfirst($lastname)." ]");
						$field->add_subfields("$subfield"=>ucfirst($firstname).", ".ucfirst($lastname));
					}
				}
				$record->insert_fields_ordered($field);
			}
# 			warn $record->as_formatted."";
			return $record,$encoding;
		}
	}
	return -1;
}


# ======================== 
#          MAIN 
#=========================
my $input = new CGI;
CGI::charset(C4::Context->preference('TemplateEncoding')); 
my $dbh = C4::Context->dbh;
my $breedingid = 1;
my $record=-1;
my $encoding="";
my $bibid;
my $file_code = $ARGV[0];

my $fc_sth = $dbh->prepare("select id,file,marc,encoding from marc_breeding where file=?");
$fc_sth->execute($file_code);
while (my $data = $fc_sth->fetchrow_hashref()){
        print "====\nCreating $data->{'id'}, $data->{'file'}, $data->{'encoding'} Biblio and Items\n";

	$breedingid =  $data->{'id'};
	## get marc data from marc_breeding
	($record,$encoding) = MARCfindbreeding($dbh,$breedingid) if ($breedingid);
	my $frameworkcode = $encoding;


	## addbiblio
	# check for a duplicate
	my ($duplicatebiblionumber,$duplicatebibid,$duplicatetitle) = FindDuplicate($record);
	if (!$duplicatebiblionumber) {
		# MARC::Record built => now, record in DB
		my $oldbibnum;
		my $oldbibitemnum;

		# prepare item data
		my @item_record;
		my @item_record_995 = $record->field('995');
		foreach my $item_record_995 (@item_record_995){
			my $item_record = MARC::Record->new();
			$item_record->append_fields($item_record_995);
			push @item_record, $item_record;

			# remove original field 995 in $record
			$record->delete_field($item_record_995);
		}

		# add to marc biblio...
		print "$bibid - add biblio ";
		($bibid,$oldbibnum,$oldbibitemnum) = NEWnewbiblio($dbh,$record,$frameworkcode);
		print "done!\n";

		foreach my $item_record (@item_record) {
			# check for item barcode # being unique
			my $item = MARCmarc2koha($dbh,$item_record);
			my $exists = itemdata($item->{'barcode'});
			warn "barcode_not_unique I will skip this one" if($exists);
			next if($exists);

			#add to item and marc995
			print "$bibid - add item ";
			my ($oldbiblionumber,$oldbibnum,$oldbibitemnum) = NEWnewitem($dbh,$item_record,$bibid) unless ($exists); 
			print "done!\n";
		}
	} else {
		print "duplicate biblio $duplicatebiblionumber\n";
	}
}
