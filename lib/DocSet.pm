package DocSet;

$VERSION = '0.08';

=head1 NAME

DocSet - documentation projects builder in HTML, PS and PDF formats

=head1 SYNOPSIS

  pod2hpp [options] base_full_path relative_to_base_configuration_file_location

Options:

  -h    this help
  -v    verbose
  -i    podify pseudo-pod items (s/^* /=item */)
  -s    create the splitted html version (not implemented)
  -t    create tar.gz (not implemented)
  -p    generate PS file
  -d    generate PDF file
  -f    force a complete rebuild
  -a    print available hypertext anchors (not implemented)
  -l    do hypertext links validation (not implemented)
  -e    slides mode (for presentations) (not implemented)
  -m    executed from Makefile (forces rebuild,
				no PS/PDF file,
				no tgz archive!)

=head1 DESCRIPTION

This package builds a docset from sources in different formats. The
generated documents can be all nicely interlinked and to have the same
look and feel.

Currently it knows to handle input formats:

* POD
* HTML

and knows to generate:

* HTML
* PS
* PDF

=head2  Modification control

Each output mode maintains its own cache (per docset) which is used
when certain source documents weren't modified since last build and
the build is running in a non-force-rebuild mode.

=head2 Definitions:

* Chapter is a single document (file).

* Link is an URL

* Docset is a collection of docsets, chapters and links.

=head2 Application Specific Features

=over

=item 1

META: not ported yet!

Generate a split version HTML, creating html file for each pod
section, and having everything interlinked of course. This version is
used best for the search.

=item 1

Complete the POD on the fly from the files in POD format. This is used
to ease the generating of the presentations slides, so one can use
C<*> instead of a long =over/=item/.../=item/=back strings. The rest
is done as before. Take a look at the special version of the html2ps
format to generate nice slides in I<conf/html2ps-slides.conf>.

=item 1

META: not ported yet!

If you turn the slides mode on, it automatically turns the C<-i> (C<*>
preprocessing) mode and does a page break before each =head tag.

=back

=head2 Look-n-Feel Customization

You can customise the look and feel of the ouput by adjusting the
templates in the directory I<example/tmpl/custom>.

You can change look and feel of the PS (PDF) versions by modifying
I<example/conf/html2ps.conf>.  Be careful that if your documentation
that you want to put in one PS or PDF file is very big and you tell
html2ps to put the TOC at the beginning you will need lots of memory
because it won't write a single byte to the disk before it gets all
the HTML markup converted to PS.


=head1 CONFIGURATION

All you have to prepare is a single config file that you then pass as
an argument to C<pod2hpp>:

  pod2hpp [options] /abs/project/root/path /full/path/to/config/file

Every directory in the source tree may have a configuration file,
which designates a docset's root. See the I<config> files for
examples. Usually the file in the root (I<example/src>) sets
operational directories and other arguments, which you don't have to
repeat in sub-docsets. Modify these files to suit your documentation
project layout.

Note that I<example/bin/build> script automatically locates your
project's directory, so you can move your project around filesystem
without changing anything.

I<example/README> explains the layout of the directories.

C<DocSet::Config> manpage explains the layout of the configuration
file.

=head1 PREREQUISITES

All these are not required if all you want is to generate only the
html version.

=over 4

=item * ps2pdf

Needed to generate the PDF version

=item * Storable

Perl module available from CPAN (http://cpan.org/)

Allows source modification control, so if you modify only one file you
will not have to rebuild everything to get the updated HTML/PS/PDF
files.

=back

=head1 SUPPORT

Notice that this tool relies on two tools (ps2pdf and html2ps) which I
don't support. So if you have any problem first make sure that it's
not a problem of these tools.

Note that while C<html2ps> is included in this distribution, it's
written in the old style Perl, so if you have patches send them along,
but I won't try to fix/modify this code otherwise. I didn't write this
utility.

=head1 BUGS

Huh? Probably many...

=head1 AUTHORS

Stas Bekman E<lt>stas (at) stason.orgE<gt>

=head1 SEE ALSO

perl(1), Pod::HTML(3), html2ps(1), ps2pod(1), Storable(3)

=head1 COPYRIGHT

This program is distributed under the Artistic License, like the Perl
itself.

=cut
