#!/usr/bin/perl -w

# build-bom.pl
#
# A simple Perl script to build BOMs from schematic files.

# TODO:
#   - Just run it in a directory and it'll automatically get all the *.sch files, and display the BOMs for each one of them.
#   - Add a option to list the parts in the order that they appear in the board layout (to make hand assembling easier).
#   - Export to various formats like CSV, JSON, HTML, etc.

use strict;
use warnings;
use Data::Dumper;

use Getopt::Long;
use XML::LibXML;

# Setup Getopt.
#my ($convert);
#GetOptions("convert|c" => \$convert);

# Gets the schematic file from the last argument.
# TODO: Append the .sch automatically if it wasn't supplied.
my $schematic = $ARGV[-1];

# Setup the XML parser and stuff.
my $parser = XML::LibXML->new();
my $xml = $parser->parse_file($schematic);

my $parts = $xml->findnodes("/eagle/drawing/schematic/parts/part");
my $items = {};

foreach my $part ($parts->get_nodelist()) {
	# Should this part be ignored?
	if ($part->getAttribute("library") =~ /(supply[0-9]*)/) {
		next;
	}

	my $value = $part->getAttribute("value");
	if (!defined $value) {
		$value = "";
	}

	my $key_name = $part->getAttribute("deviceset") . $value;
	my $item = {
		"quantity" => 1,
		"name" => $part->getAttribute("name"),
		"device" => $part->getAttribute("deviceset"),
		"value" => $value
	};

	# Check if the item already exists
	if (defined $items->{$key_name}) {
		# Just add to the quantity.
		$items->{$key_name}->{"quantity"}++;
	} else {
		# New item.
		$items->{$key_name} = $item;
	}
}

print Dumper($items);

# TODO: Make a regexp to ignore parts from certain libraries.