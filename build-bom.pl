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
use utf8;
#use Data::Dumper;

use Getopt::Long;
use XML::LibXML;
use Term::ANSIColor;


# Gets the list of parts in a hash.
sub get_parts_list {
	my ($schematic) = @_;

	# Setup the XML parser and stuff.
	my $parser = XML::LibXML->new();
	my $xml = $parser->parse_file($schematic);

	# Find the nodes.
	my $parts = $xml->findnodes("/eagle/drawing/schematic/parts/part");
	my $items = {};

	# Parse each element.
	foreach my $part ($parts->get_nodelist()) {
		# Should this part be ignored?
		if ($part->getAttribute("library") =~ /(supply[0-9]*)/) {
			next;
		}

		# Get a value (if defined).
		my $value = $part->getAttribute("value");
		if (!defined $value) {
			$value = "";
		} else {
			# Encode $value so it doesn't generate a warning when you try to print the ohms symbol.
			if (utf8::is_utf8($value)) {
				utf8::encode($value);
			}
		}

		# Create the item hash.
		my $key_name = $part->getAttribute("deviceset") . $value;
		my $item = {
			"quantity" => 1,
			"name"     => $part->getAttribute("name"),
			"device"   => $part->getAttribute("deviceset"),
			"package"  => $part->getAttribute("device"),
			"value"    => $value
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

	return $items;
}

sub print_bom {
	my ($schematic, $items) = @_;

	# Split the path.
	my @spath = split(/[\/\\]/, $schematic);
	print $spath[-1] . ":\n\n";

	foreach my $key (keys $items) {
		my $part = $items->{$key};
		my $quantity = $part->{"quantity"};
		my $name     = $part->{"name"};
		my $device   = $part->{"device"};
		my $pkg      = $part->{"package"};
		my $value    = $part->{"value"};

		# Print stuff.
		#print colored("$quantity  ", "red") . colored("$value", "yellow");
		print "$quantity  ". colored("$value", "yellow");

		if ($value ne "") {
			print " ";
		}

		print colored("$device ", "green");

		if ($pkg ne "") {
			print "($pkg)";
		}

		print "\n";
	}
}

# Setup Getopt.
#my ($convert);
#GetOptions("convert|c" => \$convert);

# Gets the schematic file from the last argument.
# TODO: Append the .sch automatically if it wasn't supplied.
my $schematic = $ARGV[-1];

my $items = get_parts_list($schematic);
#print Dumper($items);

print_bom($schematic, $items);
