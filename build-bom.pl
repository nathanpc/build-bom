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
use JSON;


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

		# Create a key name and remove any special characters from it.
		my $key_name = $part->getAttribute("deviceset") . $value;
		$key_name =~ s/[^[:print:]]/_/g;

		# Create the item hash.
		my $item = {
			"quantity" => 1,
			"names"    => [ $part->getAttribute("name") ],
			"device"   => $part->getAttribute("deviceset"),
			"package"  => $part->getAttribute("device"),
			"value"    => $value
		};

		# Check if the item already exists
		if (defined $items->{$key_name}) {
			# Just add to the quantity.
			$items->{$key_name}->{"quantity"}++;

			my @names = @{ $items->{$key_name}->{"names"} };
			push(@names, $part->getAttribute("name"));
			$items->{$key_name}->{"names"} = \@names;
		} else {
			# New item.
			$items->{$key_name} = $item;
		}
	}

	return $items;
}

# Pretty-print the BOM.
sub print_bom {
	my ($schematic, $items, $show_names) = @_;

	# Split the path.
	my @spath = split(/[\/\\]/, $schematic);
	print $spath[-1] . ":\n\n";

	foreach my $key (keys $items) {
		my $part = $items->{$key};
		my $quantity = $part->{"quantity"};
		my $names    = join(" ", @{ $part->{"names"} });
		my $device   = $part->{"device"};
		my $pkg      = $part->{"package"};
		my $value    = $part->{"value"};

		# Print stuff.
		print "$quantity ";

		if ($show_names) {
			print "[" . colored($names, "red") . "]";
		}

		print colored(" $value", "yellow");
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

sub export {
	my ($format, $schematic, $items) = @_;
	my @arr_items;

	foreach my $key (keys $items) {
		my $part = $items->{$key};
		push(@arr_items, $part);
	}

	my @spath = split(/[\/\\]/, $schematic);
	my $export_data = {
		$spath[-1] => \@arr_items
	};

	if ($format eq "json") {
		print to_json($export_data, {
			pretty => 1
		});
	} else {
		print colored("Error: ", "red") . "Unknown export format \"$format\". The available options are: json, csv, html\n";
	}
}

# The mains.
sub main {
	my $arg_num = $#ARGV;

	# Setup Getopt.
	my ($show_names, $export_format);
	GetOptions("names|n" => \$show_names,
			   "export|e=s" => \$export_format);

	# No arguments.
	if ($arg_num == -1) {
		# Show help!
		print "HELP!!!!\n";
	}

	# Gets the schematic file from the last argument and parse it.
	my $schematic = $ARGV[-1];
	my $items = get_parts_list($schematic);

	if (defined $export_format) {
		# Export the BOM.
		export($export_format, $schematic, $items);
	} else {
		# Just print the BOM as usual.
		print_bom($schematic, $items, $show_names);
	}
}


# Start the script.
main();
