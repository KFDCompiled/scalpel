#!/usr/bin/perl

use strict;
use warnings;
use HTML::Template ;
use Data::Dumper ;
use File::stat ;
use Time::localtime ;
use Digest::SHA qw ( sha512_hex ) ;

system ( 'wget https://www.utcourts.gov/cal/data/SLC_Calendar.pdf' );
system ( 'pdftotext SLC_Calendar.pdf' );

my $pdf = 'SLC_Calendar.pdf' ;
my $pdf_st = stat ( $pdf ) or die "No $pdf: $!" ; # Stat $pdf

my $sha = Digest::SHA->new(512);
$sha->addfile($pdf);
my $digest = $sha->hexdigest;

my @dft = () ; # Initialize defendant array
my @case = () ; # Initialize case number array
my @hrg = () ; # Initialize hearing type array

my $page_end = "Page" ;
my $page_declar = "3RD" ;
my $state = "UTAH" ;
my $vs = "VS." ;

# Calendar Specific variables
my $judge ;
my $judge_surname_position ;
my $judge_initials = $ARGV[0];

if ( $judge_initials eq "KBG" ) {
	$judge = "BERNARDS-GOODMAN" ;
	$judge_surname_position = 1 ;
}elsif ( $judge_initials eq "AB" ) {
	$judge = "BOYDEN" ;
	$judge_surname_position = 1 ;
}elsif ( $judge_initials eq "EHM" ) {
    $judge = "HRUBY-MILLS" ;
    $judge_surname_position = 2 ;
}elsif ( $judge_initials eq "LMJ" ) {
	$judge = "JONES" ;
	$judge_surname_position = 1 ;
}elsif ( $judge_initials eq "MSK" ) {
    $judge = "KOURIS" ;
    $judge_surname_position = 1 ;
}elsif ( $judge_initials eq "RNS" ) {
	$judge = "SKANCHY" ;
	$judge_surname_position = 1 ;
}

my $month = $ARGV[1] ;
my $date = $ARGV[2];
my $year = $ARGV[3];

if ( open ( HANDLE, "SLC_Calendar.txt" ) ) {
	# Load 2D array @file_array with lines of SLC_Calendar.txt
	my @file_array ;
	while ( my $line = <HANDLE> ) {
		chomp $line ;
		my @line_array = split ( /\s+/, $line ) ;
		push ( @file_array, \@line_array ) ;
	}

	system ( 'rm SLC_Calendar.*' ) ;

	# Find start of entries
	# NOTE: this logic depends on calendar specific $judge variable--number of words in judge's name. E.g., KBG has two words, EHM has three
	my $i = 0 ;
	do {
		$i++ ;
	} until (	( $file_array[$i][0] eq $page_end ) && 
				( $file_array[$i+2][1] eq $page_declar ) && 
				( $file_array[$i+3][$judge_surname_position] eq $judge ) &&
				( $file_array[$i+7][0] eq $month ) &&
				( $file_array[$i+7][1] == $date ) &&
				( $file_array[$i+7][2] == $year ) ) ;
	
	my $start = $i ;
	
	# Find end of entries
	do {
		$i++ ;
	} until ( 	( $file_array[$i][1] eq $page_declar ) && 
				( $file_array[$i+1][$judge_surname_position] ne $judge ) ) ;

	my $end = $i ;
	
	# Splice @entry_array from @file_array
	my @entry_array = @file_array[$start .. $end] ;

	# Parse @entry_array into arrays @dft @case @hrg
	$i = 0 ; # Reset counter
	for $i ( 0 .. $#entry_array ) {
		if ( 	( ( $entry_array[$i][2] eq "State" ) && ( $entry_array[$i][3] eq "Felony" ) ) || 
				( ( $entry_array[$i][2] eq "Other" ) && ( $entry_array[$i][3] eq "Misdemeanor" ) ) || 
				( ( $entry_array[$i][2] eq "Misdemeanor" ) && ( $entry_array[$i][3] eq "DUI" ) ) ||
				( ( $entry_array[$i][2] eq "Traffic" ) && ( $entry_array[$i][3] eq "Court" ) && ( $entry_array[$i][4] eq "Case" ) ) ||
				( ( $entry_array[$i][2] eq "{Not" ) && ( $entry_array[$i][3] eq "Applicable}" ) ) ) { 
				push ( @case, $entry_array[$i][1] ) 
		}
		if ( ( $entry_array[$i][0] eq $vs ) ) { push ( @dft, $entry_array[$i+1][0] ) }
		if ( 	( ( $entry_array[$i][2] eq "State" ) && ( $entry_array[$i][3] eq "Felony" ) ) || 
				( ( $entry_array[$i][2] eq "Other" ) && ( $entry_array[$i][3] eq "Misdemeanor" ) ) || 
				( ( $entry_array[$i][2] eq "Misdemeanor" ) && ( $entry_array[$i][3] eq "DUI" ) ) ||
				( ( $entry_array[$i][2] eq "Traffic" ) && ( $entry_array[$i][3] eq "Court" ) && ( $entry_array[$i][4] eq "Case" ) ) ||
				( ( $entry_array[$i][2] eq "{Not" ) && ( $entry_array[$i][3] eq "Applicable}" ) ) ) { 
				my @recombined_array_primary = map { @$_ } $entry_array[$i-1] ;
				my @recombined_array_alternate = map { @$_ } $entry_array[$i-4] ;
				my $recombined_string_primary = join ( ' ', @recombined_array_primary ) ;
				my $recombined_string_alternate = join ( ' ', @recombined_array_alternate ) ;
				if ( $recombined_string_primary ne '' ) { 
					push ( @hrg, $recombined_string_primary ) ;
				} elsif ( $recombined_string_alternate ne '' ) { 
					push ( @hrg, $recombined_string_alternate ) ;
				}
		}
		$i++ ;
	}	
	
	foreach ( @dft ) { $_ =~ s/,$//g; } # Clean commas from @dft
	
	# Index entries
	my @counter = () ;
	my $counter_index = 1 ;
	for my $j ( 0 .. $#dft ) {
		if ( $dft[$j] le $dft[$j+1] ) { 
			push ( @counter, $counter_index ) ;
			$counter_index++ ;
		} elsif ( $dft[$j] gt $dft[$j+1] ) {
			push ( @counter, $counter_index ) ;
			$counter_index = 1 ;
		}
	}
	
	# Generate HTML
	my $template = HTML::Template -> new ( filename => 'entries.tmpl' ) ; # Open template
	
	$template -> param ( MODIFIED => ctime( $pdf_st->mtime ) ) ; # Date-Time PDF was downloaded
	$template -> param ( DIGEST => $digest ) ;
	$template -> param ( INITIALS => $judge_initials ) ;
	$template -> param ( JUDGE => $judge );
	$template -> param ( MONTH => $month );
	$template -> param ( DATE => $date ) ;
	$template -> param ( YEAR => $year ) ;
	
	# Generate tables from @counter @dft @case @hrg
	my @loop_data = ();  # Initialize array to hold loop
	while ( @counter and @dft and @case and @hrg ) {
		my %row_data; # Get a fresh hash for the row data
	
		# Load row
		$row_data { ENTRY_NUMBER } = shift @counter ;
		$row_data { DEFENDANT } = shift @dft ;
		$row_data { CASE_NUMBER } = shift @case ;
		$row_data { HEARING_TYPE } = shift @hrg ;
	
		push ( @loop_data, \%row_data ) ; # Push a reference to this row into the loop
	}

	$template -> param ( ENTRY => \@loop_data ) ; # Assign loop data to the loop param

	print $template -> output; # Print the template output
} else {
	print "Cannot open SLC_Calendar.txt!\n";
	exit 1;
}
