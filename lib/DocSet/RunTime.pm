package DocSet::RunTime;

use strict;
use warnings;

use vars qw(@ISA @EXPORT %opts);
@ISA    = qw(Exporter);
@EXPORT = qw(get_opts);


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

my $html2ps_exec = `which html2ps` || '';
chomp $html2ps_exec;
sub can_create_ps {
    # ps2html is bundled, so we can always create PS
    return $html2ps_exec;

    # if you unbundle it make sure you write here a code similar to
    # can_create_pdf()
}

my $ps2pdf_exec = `which ps2pdf` || '';
chomp $ps2pdf_exec;
sub can_create_pdf {
    # check whether ps2pdf exists
    return $ps2pdf_exec if $ps2pdf_exec;

    print(qq{It seems that you do not have ps2pdf installed! You have
             to install it if you want to generate the PDF file
            });
    return 0;
}


1;
__END__

=head1 NAME

C<DocSet::RunTime> - RunTime Configuration

=head1 SYNOPSIS

  use DocSet::RunTime;
  if (get_opts('verbose') {
      print "verbose mode";
  }

  DocSet::RunTime::set_opt(\%args);

  DocSet::RunTime::has_storable_module();
  DocSet::RunTime::can_create_ps();
  DocSet::RunTime::can_create_pdf();


=head1 DESCRIPTION

This module is a part of the docset application, and it stores the run
time arguments. i.e. whether to build PS and PDF or to run in a
verbose mode and more.

=head1 FUNCTIONS

META: To be completed, see SYNOPSIS 

=over

=item * set_opt


=item * get_opts


=item * has_storable_module


=item * can_create_ps


=item * can_create_pdf


=back

=head1 AUTHORS

Stas Bekman E<lt>stas (at) stason.orgE<gt>

=cut
