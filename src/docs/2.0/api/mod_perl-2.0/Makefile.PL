
require 5.6.0;

use File::Find;
use File::Spec;

use ExtUtils::MakeMaker;

my $rel_path = File::Spec->catfile(('..') x 3);

WriteMakefile(
    NAME         => 'API',
    VERSION      => '0.01',
    PM           => get_pods(),
);

sub get_pods {
    my @pods = ();
    finddepth(sub{ push @pods, "$File::Find::dir/$_" if /\.pod$/ }, '.');
    return { map { s|^\./||; $_ => "\$(INST_LIB)/$_"} @pods };
}

package MY;

# when called from top mod_perl dir, it gets ../blib for all paths, so
# we want to point it back to the top blib dir.
sub MY::constants {
    my $self = shift;
    for (grep /^INST_/, keys %{ $self } ) {
        exists $self->{$_} && $self->{$_} =~ s/^\.\./$rel_path/;
    }
    $self->MM::constants;
}

