#!/usr/bin/perl

# this script builds 2 graphs from 2 data sets, expects to find a file 
# with data of name "input.data" in the script's directory, data should be
# separated with tabs, e.g:
#May 1999        156458  36976
#April 1999      134255  32570
#March 1999      112399  28482
#
# the 1st col describes a number of hostnames, 2nd - Unique IP numbers
#
# first graph (graph.gif) is a normal one
#
# second graph (pseudo-graph.gif) is much smaller and includes points,
# with no other labels, but y axis. This graph should be linked to a
# bigger one (graph.gif)
#
# Note: you need GD::Graph package to be installed in order to use this
# script.

# This script is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

# by Stas Bekman <stas@stason.org>
# Aug 14 1999
#
# updated July 16 2001 to generate jpegs instead of gifs (since gif support
# was removed from libgd)

use GD::Graph::linespoints;
use strict;

print STDERR "Processing data\n";

my @data =  read_data_from_csv("input.data")
        or die "Cannot read data from input.data";

# make the Y axis to be optimally used
my $max_y = 0;
foreach (@{$data[1]},@{$data[2]}) {
  $max_y = $_ if $_ >  $max_y ;
}
# normalize it
$max_y  = ( int $max_y / 1000 + 1 ) * 1000; 

normal_graph();

pseudo_graph();

# plot a normal graph of points with all the info as possible
sub normal_graph{
  my $my_graph = new GD::Graph::linespoints(600,400);

  $my_graph->set( 
		 x_label => 'Months',
		 y_label => 'Counts',
		 title => "mod_perl usage survey (numbers are by courtesy of netcraft.com).",
		 y_max_value => $max_y,
		 y_label_skip => 1,
		 x_label_skip => 3,
		 x_labels_vertical => 1,
		 x_label_position => 1/2,
		 markers => [ 1, 7 ],
		 marker_size => 2,
		 transparent => 1,
		 t_margin => 10, 
		 b_margin => 10, 
		 l_margin => 10, 
		 r_margin => 10,

		 two_axes => 1,
		 logo => 'logo.png',
		 logo_position => 'LL',
		);

  #$my_graph->set( dclrs => [ qw(green pink blue cyan) ] );

  $my_graph->set_x_label_font(GD::gdMediumBoldFont);
  $my_graph->set_y_label_font(GD::gdMediumBoldFont);
  $my_graph->set_x_axis_font(GD::gdMediumBoldFont);
  $my_graph->set_y_axis_font(GD::gdMediumBoldFont);
  $my_graph->set_title_font(GD::gdGiantFont);

  $my_graph->set_legend('Hostnames','Unique IP numbers' );
  $my_graph->set_legend_font(GD::gdMediumBoldFont);


  open IMG, '>graph.jpg' or die $!;
  print IMG $my_graph->plot(\@data)->jpeg(70);
  close IMG;
#  $my_graph->plot_to_gif( "graph.gif", \@data );

}

# plot a small graph of points with as least info as possible
sub pseudo_graph{
  my $my_graph = new GD::Graph::linespoints(350,200);

    # in this graph we don't want X labels to be printed
  for (0..$#{$data[0]}) {
    $data[0]->[$_] = "";
  }

  $my_graph->set( 
		 y_max_value => $max_y,
		 y_label_skip => 0,
		 x_label_skip => 1,
		 x_labels_vertical => 1,
		 x_label_position => 1/2,
		 markers => [ 1, 7 ],
		 marker_size => 2,
		 transparent => 1,
		 t_margin => 10, 
		 b_margin => 10, 
		 l_margin => 10, 
		 r_margin => 10,
		 two_axes => 0,

		 logo => 'logo-middle.png',
		 logo_position => 'UL',
		);

  #$my_graph->set( dclrs => [ qw(green pink blue cyan) ] );

  $my_graph->set_x_label_font(GD::gdMediumBoldFont);
  $my_graph->set_y_label_font(GD::gdSmallFont);
  $my_graph->set_x_axis_font(GD::gdMediumBoldFont);
  $my_graph->set_y_axis_font(GD::gdSmallFont);
  $my_graph->set_title_font(GD::gdGiantFont);

  $my_graph->set_legend('Hostnames','Unique IP numbers' );
  $my_graph->set_legend_font(GD::gdSmallFont);


  open IMG, '>pseudo-graph.jpg' or die $!;
  print IMG $my_graph->plot(\@data)->jpeg(70);
  close IMG;
  #$my_graph->plot_to_gif( "pseudo-graph.gif", \@data );


}

sub read_data_from_csv
{
        my $fn = shift;
        my @d = ();

        open(ZZZ, $fn) || return ();

        while (<ZZZ>)
        {
                chomp;
                # you might want Text::CSV here
                my @row = split /\t/;

                for (my $i = 0; $i <= $#row; $i++)
                {
                        undef $row[$i] if ($row[$i] eq 'undef');
                        unshift @{$d[$i]}, $row[$i];
                }
        }

        close (ZZZ);

        return @d;
}

