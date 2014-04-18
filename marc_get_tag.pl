#!/usr/bin/perl -w
############################################################################
#                          new_split.pl  -  description                    #
#                             -------------------                          #
#    copyright            : (C) 2000 by Yu-Chin Tsai                       #
#    email                : tlinux.tsai@gmail.com                          #
############################################################################
############################################################################
#                                                                          #
#   This program is free software; you can redistribute it and#or modify   #
#   it under the terms of the GNU General Public License as published by   #
#   the Free Software Foundation; either version 2 of the License, or      #
#   (at your option) any later version.                                    #
#                                                                          #
#############################################################################

use MARC::Batch;
use MARC::Record;
use MARC::Field;

my $file_name = $ARGV[0];
my $batch = MARC::Batch->new('USMARC',$file_name);

$batch->strict_off();
$batch->warnings_off();

my %tags;
while ( my $record = $batch->next() ) {
    my @fields = $record->fields();
    foreach my $field (@fields){
	my $tag = $field->tag();
        my @subtag;
        #warn "tag = ".$tag;
	next if ($tag eq '001');
	next if ($tag eq '008');
        if (defined($record->field($tag))){
	    @subtag = $record->field($tag)->subfields();
	    foreach (@subtag){
	        $tags{"$tag@{$_}[0]"}++;
	    }
        }
    }
}

foreach (sort { $a <=> $b } keys(%tags)){
    print "$_ = $tags{$_}\n";
}
