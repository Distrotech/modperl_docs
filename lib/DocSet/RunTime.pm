package DocSet::RunTime;

# META: this class acts as Singleton, consider to actually use
# Class::Singleton

use strict;
use warnings;

use File::Spec::Functions;
use File::Find;

use DocSet::Util;
use Carp;

use vars qw(@ISA @EXPORT %opts);
@ISA    = qw(Exporter);
@EXPORT = qw(get_opts find_src_doc set_render_obj get_render_obj unset_render_obj);

my %src_docs;
my %exts;
my $render_obj;

# = (
#          'docs/2.0' => {
#                         'devel/core_explained/core_explained.pod' => 1,
#                        },
#         );

sub set_opt {
    my(%args) = ();
    if (@_ == 1) {
        my $arg = shift;
        my $ref = ref $arg;
        if ($ref) {
            %args = $ref eq 'HASH' ? %$arg : @$arg;
        } else {
            die "must be a ref to or an array/hash";
        }
    } else {
        %args = @_;
    }
    @opts{keys %args} = values %args;
}

sub get_opts {
    my $opt = shift;
    exists $opts{$opt} ? $opts{$opt} : '';
}

# check whether we have a Storable avalable
use constant HAS_STORABLE => eval { require Storable; };
sub has_storable_module {
    return HAS_STORABLE;
}

# check for existence of html2ps and ps2pdf

my $html2ps_exec = which('html2ps');
sub can_create_ps {
    # ps2html is bundled, so we can always create PS
    return $html2ps_exec if $html2ps_exec;

    print 'It seems that you do not have html2ps installed! You have',
        'to install it if you want to generate the PDF file';
    return 0;

    # if you unbundle it make sure you write here a code similar to
    # can_create_pdf()
}

my $ps2pdf_exec = which('ps2pdf');
sub can_create_pdf {
    # check whether ps2pdf exists
    return $ps2pdf_exec if $ps2pdf_exec;

    print 'It seems that you do not have ps2pdf installed! You have',
        'to install it if you want to generate the PDF file';
    return 0;
}

sub scan_src_docs {
    my($base, $ra_search_paths, $ra_search_exts) = @_;

    %exts = map {$_ => 1} @{$ra_search_exts || []};

    my @ext_accept_pattern = map {quotemeta($_)."\$"} keys %exts;
    my $rsub_keep_ext = 
        build_matchmany_sub(\@ext_accept_pattern);

    my %seen;
    for my $rel_path (@{$ra_search_paths || []}) {
        my $full_path = catdir $base, $rel_path;
        die "$full_path is not a dir" unless -d $full_path;

        my @seen_pattern = map {"^".quotemeta($_)} keys %seen;
        my $rsub_skip_seen = 
            build_matchmany_sub(\@seen_pattern);

        my $full_path_regex = quotemeta $full_path;
        $src_docs{$rel_path} = {
            map { $_ => 1 }
                map {s|$full_path_regex/||; $_}
                grep $rsub_keep_ext->($_),   # get files with wanted exts
                grep !$rsub_skip_seen->($_), # skip seen base dirs
                @{ expand_dir($full_path) }
        };

        note "Scanning for src files: $full_path";
        $seen{$full_path}++;
    }

    #dumper \%src_docs;
}

sub find_src_doc {
    my($resource_rel_path) = @_;

    for my $path (keys %src_docs) {
        for my $ext (keys %exts) {
#print qq{Try:  $path :: $resource_rel_path.$ext\n};
            if (exists $src_docs{$path}{"$resource_rel_path.$ext"}) {
#print qq{Found $path/$resource_rel_path.$ext\n};
                return join '/', $path, "$resource_rel_path.$ext";
            }

        }
    }

}

# set render object: sort of Singleton, it'll complain aloud if the
# object is set over the existing object, without first unsetting it
sub set_render_obj {
    Carp::croak("usage: set_render_obj(\$obj) ") unless @_;
    Carp::croak("unset render_obj before setting a new one") if $render_obj;
    Carp::croak("undefined render_obj passed") unless defined $_[0];
    $render_obj = shift;
}

sub get_render_obj { 
    Carp::croak("render_obj is not available") unless $render_obj;

    return $render_obj;
}

sub unset_render_obj {
    Carp::croak("render_obj is not set") unless $render_obj;

    undef $render_obj;
}

1;
__END__

=head1 NAME

C<DocSet::RunTime> - RunTime Configuration

=head1 SYNOPSIS

  use DocSet::RunTime;

  # run time options
  DocSet::RunTime::set_opt(\%args);
  if (get_opts('verbose') {
      print "verbose mode";
  }

  # hosting system capabilities testing
  DocSet::RunTime::has_storable_module();
  DocSet::RunTime::can_create_ps();
  DocSet::RunTime::can_create_pdf();

  # source documents lookup
  DocSet::RunTime::scan_src_docs($base_path, \@search_paths, \@search_exts);
  my $full_src_path = find_src_doc($resource_rel_path);

  # rendering object singleton
  set_render_obj($obj);
  unset_render_obj();
  $obj = get_render_obj();

=head1 DESCRIPTION

This module is a part of the docset application, and it stores the run
time arguments, caches results of expensive calls and provide
Singleton-like service to the whole system.

=head1 FUNCTIONS

META: To be completed, see SYNOPSIS 

=head2 Run Time Options

Only get_opts() method is exported by default.

=over

=item * set_opt(\%args)


=item * get_opts()


=back

=head2 Hosting System Capabilities Testing

These methods test the capability of the system and are a part of the
runtime system to perform the checking only once.

=over

=item * has_storable_module


=item * can_create_ps


=item * can_create_pdf

=back

=head2 Source Documents Lookup

A system for mapping L<> escapes to the located of the rendered
files. This system scans once the C<@search_paths> for files with
C<@search_exts> starting from C<$base_path> using scan_src_docs(). The
C<@search_paths> and C<@search_exts> are configured in the
I<config.cfg> file. For example:

    dir => {
             # search path for pods, etc. must put more specific paths first!
             search_paths => [qw(
                 foo/bar
                 foo
                 .
             )],
             # what extensions to search for
             search_exts => [qw(pod pm html)],
 	    },	

So for example if the base path is I<~/myproject/src>, the files with
extensions I<.pod>, I<.pm> and I<.html> will be searched in
I<~/myproject/src/foo/bar>, I<~/myproject/src/foo> and
I<~/myproject/src>.

Notice that you must specify the more specific paths first, since for
optimization the seen paths are skipped. Therefore in our example the
more explicit path I<foo/bar> was listed before the more general
I<foo>.

When the POD parser finds a L<> sequence it indentifies the resource
part and passes it to the find_src_doc() which looks up for this file
in the cache and returns its original (src) location, which can be
then easily converted to the final location and optionally adjusting
the extension, e.g. when the POD file is converted to HTML.

Only the find_src_doc() function is exported by default.

=over

=item * scan_src_docs($base_path, \@search_paths, \@search_exts);

=item * find_src_doc($resource_rel_path);

returns C<undef> if nothing was found.

=back


=head2 Rendering Object Singleton

Since the rendering process may happen by a third party system, into
which we provide hooks or overload some of its methods, it's quite
possible that we won't be able to access the current document (or
better rendering) object. One solution would be to have a global
package variable, but that's very error-prone. Therefore the used
solution is to provide a hook into a RunTime environment setting the
current rendering object when the rendering of a single page starts
via C<set_render_obj($obj)> and unsetting it when it's finished via
unset_render_obj(). Between these two moments the current rendering
object can be retrieved with get_render_obj() method.

Notice that this is all possible in the program which is not threaded,
or/and only one rendering process exists at any given time from its
start to its end.

All three methods are exported by default.

=over

=item * set_render_obj($obj)

Sets the current rendering object.

You cannot set a new rendering object before the previous one is
unset. This is in order to make sure that one document won't use by
mistake a rendering object of another document. So when the rendering
is done remember to call the unset_render_obj() function.

=item * unset_render_obj()

Unsets the currently set rendering object.

=item * get_render_obj()

Retrieves the currently set rendering object or complains aloud if it
cannot find one.

=back

=head1 AUTHORS

Stas Bekman E<lt>stas (at) stason.orgE<gt>

=cut
