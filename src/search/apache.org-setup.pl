# to use the setup at home, simply add to httpd.conf:
# SetEnv SWISH_BINARY_PATH /usr/local/bin/swish-e
# adjust to the real path

# on daedalus (the production server) we cannot modify the config file
# so we do it here
BEGIN {
    require Sys::Hostname;
    my $hostname = Sys::Hostname::hostname();

    if ($hostname && ($hostname eq 'minotaur.apache.org' ||
                      $hostname eq 'daedalus.apache.org')) {
        $ENV{SWISH_BINARY_PATH} = "/home/perlwww/bin/swish-e";

        unshift @INC,
            qw(
               /home/perlwww/lib/perl5/5.00503
               /home/perlwww/lib/perl5/site_perl/5.005
               /home/perlwww/lib/perl5/site_perl/
               /home/perlwww/lib/perl5/site_perl/
               /home/perlwww/lib/perl5/
              );

    }
}

1;
