#!/usr/bin/perl

use strict;
use warnings;

use Template;

use vars qw(%data);
require "./data.pl";

my $tmpl_file = "maillist.tmpl";
my $config = {
              INCLUDE_PATH => ".",
              OUTPUT_PATH  => ".",
             };
my $template = Template->new($config) or die $Template::ERROR, "\n";

while (my ($k,$v) = each %data) {
    generate($k, $v);
}

sub generate {
    my ($node, $data) = @_;

    my $filename = "$node.pod";
    print "generating $filename\n";

    #  use Data::Dumper;
    #  print Dumper \@search_path;
    my $vars = {list => $data};
    $template->process($tmpl_file, $vars, $filename)
        or die "error: ", $template->error(), "\n";

}
