#!/usr/bin/perl

use strict;
use warnings;

use Template;
use Data::Dumper;
use HTML::Entities;

my $tmpl_file = "people.tmpl";
my $html_file = "people.html";
my $config = {
              INCLUDE_PATH => ".",
              OUTPUT_PATH  => ".",
             };
my $template = Template->new($config) or die $Template::ERROR, "\n";

my $small_list = 'other.list';
my $small_list_tmpl = 'other.tmpl';
my $small_list_out = 'other.pod';

###############################################################################

my @files = sort( @ARGV ? @ARGV : <*.txt> );

my @data = ();
for my $file (@files) {
    push @data, process($file);
}
generate($html_file, \@data);

# generate list of minor contributors.
small_list($small_list, $small_list_tmpl, $small_list_out);


sub process {
    my $file = shift;

    print "+++ Processing $file\n";

    open my $fh, $file or die "cannot open $file: $!";
    local $/ = "";
    my $headers = <$fh>;

    my @body = <$fh>;   # read in paragraph mode
    close $fh;

    # headers
    my %headers = map {/(\w+)\s*:\s+(.*)/; ($1, $2) } 
        split /\n/, $headers;
    warn "Number of keys in headers doesn't match number of values --
    maybe you forgot a space between the colon and the value?" 
        if scalar keys(%headers) != scalar values(%headers);

    my $name = delete $headers{Name};
    die "No name for $file" unless $name;

    my $email = delete $headers{Email} or delete $headers{'E-mail'};
    # antispam
    $email =~ s/\@/ (at) / if $email;

    my $url = delete $headers{URL};
    my $image = delete $headers{Image};
    
    my $summary = delete $headers{Summary} || '';  # for TOC

    (my $id = $file) =~ s/\.txt$//;    # to use as a unique ID in <a
                                       # name=""> tags and for TOC
                                       # linking

#    print Dumper \%headers;
#    print "headers:\n$headers\n";
#    print "body:\n$body\n";

    my %data = (
                name   => $name,
                email  => $email,
                url    => $url,
                image  => $image,
                id     => $id,
                summary => $summary,
                info   => \%headers,
               );

    # cleanup for pod
    _encode(\%data);

    # body is kept as is, with HTML and all, but <p> tags are added around paras.

    $data{body} = '';  # to avoid uninitialized errors.
    for (@body) {
        $data{body} .= "<p>$_</p>\n";
    }

    return \%data;
}

sub generate {
    my ($filename, $data) = @_;
    print "+++ writing $filename using template $tmpl_file\n";

    #  print Dumper \@search_path;
    my $vars = { people => $data };
    $template->process($tmpl_file, $vars, $filename)
        or die "error: ", $template->error(), "\n";

}

sub encode { 
    encode_entities($_[0]);
}
sub _encode {
    my $ref = ref $_[0];
    if (!$ref) {
        encode($_[0]) if defined $_[0];
    } elsif ($ref eq 'ARRAY') {
        _encode($_) for @{$_[0]};
    } elsif ($ref eq 'HASH') {
        _encode($_[0]->{$_}) for keys %{$_[0]};
    } else {
        # nothing
    }
}

sub small_list {
    my ($file, $tmpl, $out) = @_;

    print "+++ Processing $file\n";
    
    open my $fh, $file or die "cannot open $file: $!";
    my @list = <$fh>;
    close $fh;

    @list = sort @list;
    
    
    print "+++ writing $out using template $tmpl\n";
    my $vars = { people => \@list };
    $template->process($tmpl, $vars, $out)
        or die "error: ", $template->error(), "\n";

}
