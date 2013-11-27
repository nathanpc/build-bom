#!/usr/bin/perl -w

# build-bom.pl
#
# A simple Perl script to build BOMs from schematic files.

use strict;
use warnings;
use utf8;
#use Data::Dumper;

use Getopt::Long;
use XML::LibXML;
use Term::ANSIColor;
use JSON;
use File::Slurp;


# Usage message.
sub usage {
	print "Usage: build_bom.pl [-n] [-e format] schematic_file|directory\n\n";

	print "Arguments:\n";
	print "    -h\t\tThis message\n";
	print "    -s\t\tHide the component IDs\n";
	print "    -e format\tExport BOM (pipe the output into a file to export to a file)\n";

	print "\nExport Formats: json, csv, html\n";
}

sub check_program {
	my ($filename) = @_;
	my $header = "";

	# Read the file header.
	open(SCHFILE, '<', $filename);
	for (my $line = 0; $line < 3; $line++) {
		$header .= <SCHFILE>;
	}
	close(SCHFILE);

	if ($header =~ /\<\!DOCTYPE eagle SYSTEM "eagle.dtd"\>/) {
		return "eagle";
	} elsif ($header =~ /Cmp-Mod/) {
		return "kicad";
	} else {
		print colored("Error: ", "red") . "Couldn't identify the file format.\n\n";
		print "Supported formats are:\n";
		print "  - *.sch EAGLE schematics\n";
		print "  - *.cmp KiCAD file\n";

		die;
		#return "unknown";
	}
}

# Gets the list of parts in a hash.
sub get_parts_list {
	my ($program, $schematic) = @_;
	my $items = {};

	if ($program eq "eagle") {
		# EAGLE.

		# Setup the XML parser and stuff.
		my $parser = XML::LibXML->new();
		my $xml = $parser->parse_file($schematic);

		# Find the nodes.
		my $parts = $xml->findnodes("/eagle/drawing/schematic/parts/part");

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
	} elsif ($program eq "kicad") {
		# KiCAD.
		my $file = read_file($schematic);

		# Iterate through the component block.
		while ($file =~ /BeginCmp(.+?)EndCmp/sg) {
			my $cmpblock = $1;
			chomp $cmpblock;

			my ($key_name, $name, $device, $pkg, $value);

			# Iterate through the block lines.
			while ($cmpblock =~ /(.+)[^;\n]/g) {
				my @pair = split(/\s+=\s+/, $1);
				$pair[1] =~ s/;//;

				if ($pair[0] eq "Reference") {
					# Part ID.
					$name = $pair[1];
				} elsif ($pair[0] eq "ValeurCmp") {
					# Check if it's a value or a device name.
					if ($pair[1] =~ /^[0-9]+[a-zA-Z]+$/) {
						# Value.
						$value = $pair[1];
						$device = "";
					} else {
						# Device.
						$device = $pair[1];
						$value = "";
					}
				} elsif ($pair[0] eq "IdModule") {
					$pkg = $pair[1];
				}
			}

			$key_name = "$pkg-$value$device";
			my $item = {
				"quantity" => 1,
				"names"    => [ $name ],
				"device"   => $device,
				"package"  => $pkg,
				"value"    => $value
			};

			# Check if the item already exists
			if (defined $items->{$key_name}) {
				# Just add to the quantity.
				$items->{$key_name}->{"quantity"}++;

				my @names = @{ $items->{$key_name}->{"names"} };
				push(@names, $name);
				$items->{$key_name}->{"names"} = \@names;
			} else {
				# New item.
				$items->{$key_name} = $item;
			}
		}
	}

	return $items;
}

# Pretty-print the BOM.
sub print_bom {
	my ($ref_items, $show_names) = @_;
	my @items = @{ $ref_items };
	my $print_separator = 0;

	foreach my $schematic (@items) {
		# Print filename separator?
		if ($print_separator) {
			print "\n\n";
		}

		# Print filename.
		print $schematic->{"name"} . ":\n\n";
		$print_separator = 1;

		foreach my $key (keys $schematic->{"parts"}) {
			my $part     = $schematic->{"parts"}->{$key};
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
}

# Exporting.
sub export {
	my ($format, $ref_items) = @_;
	my @items = @{ $ref_items };
	my $export_data = {};

	if ($format eq "json") {
		# JSON
		foreach my $schematic (@items) {
			my @arr_items;
			foreach my $key (keys $schematic->{"parts"}) {
				push(@arr_items, $schematic->{"parts"}->{$key});
			}

			$export_data->{$schematic->{"name"}} = \@arr_items;
		}

		# Print JSON.
		print to_json($export_data, {
			pretty => 1
		});
	} elsif ($format eq "csv") {
		# CSV
		foreach my $schematic (@items) {
			print $schematic->{"name"} . ",\n";

			foreach my $key (keys $schematic->{"parts"}) {
				my $part     = $schematic->{"parts"}->{$key};
				my $quantity = $part->{"quantity"};
				my $names    = join(" ", @{ $part->{"names"} });
				my $device   = $part->{"device"};
				my $pkg      = $part->{"package"};
				my $value    = $part->{"value"};

				print "$quantity,$names,$value,$device,$pkg,\n";
			}

			print "\n";
		}
	} elsif ($format eq "html") {
		# HTTP
		print "<!DOCTYPE html>\n<html>\n\t<head>\n";
		print "\t\t<meta charset=\"utf-8\">\n";
		print "\t\t<title>Bill of Materials</title>\n";
		print "\t\t<style>table > tbody > tr > td { padding: 0px 10px; }\nh3 { margin: 0; }\ntable { margin-bottom: 30px; }</style>\n";
		print "\t</head>\n\t<body>\n";

		foreach my $schematic (@items) {
			print "\t\t<h3>" . $schematic->{"name"} . "</h3>\n";

			# Table header.
			print "\t\t<table><thead>\n\t\t\t<tr>\n";
			print "\t\t\t\t<th>Quantity</th>\n";
			print "\t\t\t\t<th>IDs</th>\n";
			print "\t\t\t\t<th>Value</th>\n";
			print "\t\t\t\t<th>Device</th>\n";
			print "\t\t\t\t<th>Package</th>\n";
			print "\t\t\t</tr></thead><tbody>\n";

			# Populate table.
			foreach my $key (keys $schematic->{"parts"}) {
				my $part     = $schematic->{"parts"}->{$key};
				my $quantity = $part->{"quantity"};
				my $names    = join(" ", @{ $part->{"names"} });
				my $device   = $part->{"device"};
				my $pkg      = $part->{"package"};
				my $value    = $part->{"value"};

				print "\t\t\t<tr>\n";
				print "\t\t\t\t<td>$quantity</td>\n";
				print "\t\t\t\t<td>$names</td>\n";
				print "\t\t\t\t<td>$value</td>\n";
				print "\t\t\t\t<td>$device</td>\n";
				print "\t\t\t\t<td>$pkg</td>\n";
				print "\t\t\t</tr>\n";
			}

			# Close table.
			print "</tbody>\n\t\t</table>\n\n";
		}

		# Close the rest.
		print "\t</body>\n</html>\n";
	} else {
		# Unknown
		print colored("Error: ", "red") . "Unknown export format \"$format\". The available options are: json, csv, html\n";
	}
}

# The mains.
sub main {
	my $arg_num = $#ARGV;

	# Setup Getopt.
	my ($hide_names, $export_format, $show_help);
	GetOptions("simple|s" => \$hide_names,
			   "help|h" => \$show_help,
			   "export|e=s" => \$export_format);

	# No arguments or -h.
	if ($arg_num == -1 or $show_help) {
		# Show help!
		usage();
		return;
	}

	# Gets the schematic file from the last argument and parse it.
	my $schematic = $ARGV[-1];
	my @items;

	# Check if it's a file or a directory.
	if (-f $schematic) {
		# File.
		my @spath = split(/[\/\\]/, $schematic);
		my $program = check_program($schematic);

		# Append the schematic.
		push(@items, {
			"name" => $spath[-1],
			"parts" => get_parts_list($program, $schematic)
		});
	} elsif (-d $schematic) {
		# Directory.
		opendir(DIR, $schematic) or die $!;

		while (my $file = readdir(DIR)) {
			# Only files with supported extensions, please...
			next unless (-f "$schematic/$file");
			next unless ($file =~ /\.(sch)|(cmp)$/);
			my $program = check_program("$schematic/$file");

			# Append the schematic.
			push(@items, {
				 "name" => $file,
				 "parts" => get_parts_list($program, "$schematic/$file")
			});
		}

		closedir(DIR);
	} else {
		# If you get here there's some really fucked up shit happening.
		print colored("Error: ", "red") . "Couldn't recognize the type of input you entered\n\n";
		usage();

		return;
	}

	if (defined $export_format) {
		# Export the BOM.
		export($export_format, \@items);
	} else {
		# Just print the BOM as usual.
		print_bom(\@items, !$hide_names);
	}
}


# Start the script.
main();
