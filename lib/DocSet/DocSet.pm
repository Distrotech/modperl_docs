package DocSet::DocSet;

use strict;
use warnings;

use DocSet::Util;
use DocSet::RunTime;
use DocSet::Cache ();
use DocSet::Doc ();
use DocSet::NavigateCache ();

use vars qw(@ISA);
use DocSet::Config ();
@ISA = qw(DocSet::Config);

########
sub new {
    my $class = shift;
    my $self = bless {}, ref($class)||$class;
    $self->init(@_);
    return $self;
}


sub init {
    my($self, $config_file, $parent_o, $src_rel_dir) = @_;

    $self->read_config($config_file);

    # are we inside a super docset?
    if ($parent_o and ref($parent_o)) {
        $self->{parent_o} = $parent_o;
        $self->merge_config($src_rel_dir);
    }

}

sub scan {
    my($self) = @_;

    my $src_root = $self->get_dir('src_root');

    # each output mode need its own cache, because of the destination
    # links which are different
    my $mode = $self->get('tmpl_mode');
    my $cache = DocSet::Cache->new("$src_root/cache.$mode.dat");
    $self->cache($cache); # store away

    # cleanup the cache or rebuild
    $cache->invalidate if get_opts('rebuild_all');

    # cache the index node meta data
    $cache->index_node($self->get('id'),
                       $self->get('title'),
                       $self->get('abstract')
                      );

    # cache the location of the parent node cache
    if (my $parent_o = $self->get('parent_o')) {
        my $parent_src_root   = $parent_o->get_dir('src_root');
        (my $rel2parent_src_root = $src_root) =~ s|$parent_src_root||;
        my $rel_dir = join '/', ("..") x ($rel2parent_src_root =~ tr|/|/|);
        my $parent_cache_path = "$parent_src_root/cache.$mode.dat";
        $cache->parent_node($parent_cache_path,
                            $self->get('id'),
                            $rel_dir);
        $self->set_dir(rel_parent_root => $rel_dir);
    }

    ###
    # scan the nodes of the current level and cache the meta and other
    # data

    my $hidden = 0;
    my @nodes_by_type = @{ $self->nodes_by_type };
    while (@nodes_by_type) {
        my($type, $data) = splice @nodes_by_type, 0, 2;
        if ($type eq 'docsets') {
            my $docset = $self->docset_scan_n_cache($data, $hidden);
            $self->object_store($docset)
                if defined $docset and ref $docset;

        } elsif ($type eq 'chapters') {
            my $chapter = $self->chapter_scan_n_cache($data, $hidden);
            $self->object_store($chapter)
                if defined $chapter and ref $chapter;

        } elsif ($type eq 'links') {
            $self->link_scan_n_cache($data, $hidden);
            # we don't need to process links

        } else {
            # nothing
        }

    }

    # the same but for the hidden objects
    $hidden = 1;
    my @hidden_nodes_by_type = @{ $self->hidden_nodes_by_type };
    while (@hidden_nodes_by_type) {
        my($type, $data) = splice @hidden_nodes_by_type, 0, 2;
        if ($type eq 'docsets') {
            my $docset = $self->docset_scan_n_cache($data, $hidden);
            $self->object_store($docset)
                if defined $docset and ref $docset;

        } elsif ($type eq 'chapters') {
            my $chapter = $self->chapter_scan_n_cache($data, $hidden);
            $self->object_store($chapter)
                if defined $chapter and ref $chapter;

        } else {
            # nothing
        }
    }

    $cache->node_groups($self->node_groups);

    # sync the cache
    $cache->write;

}


sub docset_scan_n_cache {
    my($self, $src_rel_dir, $hidden) = @_;

    my $src_root = $self->get_dir('src_root');
    my $cfg_file =  "$src_root/$src_rel_dir/config.cfg";
    my $docset = $self->new($cfg_file, $self, $src_rel_dir);
    $docset->scan;

    # cache the children meta data
    my $id = $docset->get('id');
    my $meta = {
                title    => $docset->get('title'),
                link     => "$src_rel_dir/index.html",
                abstract => $docset->get('abstract'),
               };
    $self->cache->set($id, 'meta', $meta, $hidden);

    return $docset;
}


sub link_scan_n_cache {
    my($self, $link, $hidden) = @_;
    my %meta = %$link; # make a copy
    my $id = delete $meta{id};
    $self->cache->set($id, 'meta', \%meta, $hidden);
}


sub chapter_scan_n_cache {
    my($self, $src_file, $hidden) = @_;

    my $trg_ext = $self->trg_ext();

    my $src_root      = $self->get_dir('src_root');
    my $dst_root      = $self->get_dir('dst_root');
    my $abs_doc_root  = $self->get_dir('abs_doc_root');
    my $src_path      = "$src_root/$src_file",

    my $src_ext = filename_ext($src_file)
        or die "cannot get an extension for $src_file";
    my $src_mime = $self->ext2mime($src_ext)
        or die "unknown extension: $src_ext";
    (my $basename = $src_file) =~ s/\.$src_ext$//;

    # destination paths
    my $rel_dst_path = "$basename.$trg_ext";
    my $rel_doc_root = "./";
    $rel_dst_path =~ s|^\./||; # strip the leading './'
    $rel_doc_root .= join '/', ("..") x ($rel_dst_path =~ tr|/|/|);
    $rel_doc_root =~ s|/$||; # remove the last '/'
    my $dst_path  = "$dst_root/$rel_dst_path";

    # push to the list of final chapter paths
    # e.g. used by PS/PDF build, which needs all the chapters
    $self->trg_chapters($rel_dst_path);

    ### to rebuild or not to rebuild
    my($should_update, $reason) = should_update($src_path, $dst_path);
    if (!$should_update) {
        note "--- $src_file: skipping ($reason)";
        return undef;
    }

    ### init
    note "+++ $src_file: processing ($reason)";
    my $dst_mime = $self->get('dst_mime');
    my $conv_class = $self->conv_class($src_mime, $dst_mime);
    require_package($conv_class);

    my $chapter = $conv_class->new(
         tmpl_mode    => $self->get('tmpl_mode'),
         tmpl_root    => $self->get_dir('tmpl'),
         src_uri      => $src_file,
         src_path     => $src_path,
         dst_path     => $dst_path,
         rel_dst_path => $rel_dst_path,
         rel_doc_root => $rel_doc_root,
         abs_doc_root => $abs_doc_root,
        );

    $chapter->scan();

    # cache the chapter's meta and toc data
    $self->cache->set($src_file, 'meta', $chapter->meta, $hidden);
    $self->cache->set($src_file, 'toc',  $chapter->toc,  $hidden);

    return $chapter;

}

sub render {
    my($self) = @_;

    # copy non-pod files like images and stylesheets
    $self->copy_the_rest;

    my $src_root = $self->get_dir('src_root');

    # each output mode need its own cache, because of the destination
    # links which are different
    my $mode = $self->get('tmpl_mode');
    my $cache = DocSet::Cache->new("$src_root/cache.$mode.dat");

    # render the objects no matter what kind are they
    for my $obj ($self->stored_objects) {
        $obj->render($cache);
    }

    $self->complete;

}

####################
sub copy_the_rest {
    my($self) = @_;

    my @copy_files = @{ $self->files_to_copy || [] };

    return unless @copy_files;

    my $src_root = $self->get_dir('src_root');
    my $dst_root = $self->get_dir('dst_root');
    note "+++ Copying the non-processed files from $src_root to $dst_root";
    foreach my $src_path (@copy_files){
        my $dst_path = $src_path;
#        # some OSs's File::Find returns files with no dir prefix root
#        # (that's what ()* is for
#        $dst_path =~ s/(?:$src_root)*/$dst_root/; 
        $dst_path =~ s/$src_root/$dst_root/;
            
        # to rebuild or not to rebuild
        my($should_update, $reason) = 
            should_update($src_path, $dst_path);
        if (!$should_update) {
            note "--- skipping cp $src_path $dst_path ($reason)";
            next;
        }
        note "+++ processing cp $src_path $dst_path ($reason)";
        copy_file($src_path, $dst_path);
    }
}


# abstract classes
sub complete {}

1;
__END__

=head1 NAME

C<DocSet::DocSet> - An abstract docset generation class

=head1 SYNOPSIS

  use DocSet::DocSet::HTML ();
  my $docset = DocSet::DocSet::HTML->new($config_file);
  
  # must start from the abs root
  chdir $abs_root;
  
  # must be a relative path to be able to move the generated code from
  # location to location, without adjusting the links
  $docset->set_dir(abs_root => ".");
  $docset->scan;
  $docset->render;

=head1 DESCRIPTION

C<DocSet::DocSet> processes a docset, which can include other docsets,
documents and links. In the first pass it scans the linked to it
documents and other docsets and caches this information and the
objects for a later peruse. In the second pass the stored objects are
rendered. And the docset is completed.

This class cannot be used on its own and has to be subclassed and
extended, by the sub-classes which has a specific to input and output
formats of the documents that need to be processed. It handles only
the partial functionality which doesn't require format specific
knowledge.

=head2 METHODS

This class inherits from C<DocSet::Config> and you will find the
documentation of methods inherited from this class in its pod.

The following "public" methods are implemented in this super-class:

=over

=item * new

  $class->new($config_file, $parent_o, $src_rel_dir);

=item * init

  $self->init($config_file, $parent_o, $src_rel_dir);

=item * scan

  $self->scan();

Scans the docset for meta data and tocs of its items and caches this
information and the item objects.

=item * render

  $self->render();

Calls the render() method of each of the stored objects and creates an
index page linking all the items.

=item * copy_the_rest

  $self->copy_the_rest()

Copies the items which aren't processed (i.e. images, css files, etc).

=back

=head2 ABSTRACT METHODS

The following methods should be implemented by the sub-classes.

=over

=item * parse

=item * retrieve_meta_data

=item * convert

=item * complete

  $self->complete();

put here anything that should be run after all the items have been
rendered and all the meta info has been collected. i.e. generation of
the I<index> file, to link to all the links and the parent node if
such exists.

=back

=head1 AUTHORS

Stas Bekman E<lt>stas (at) stason.orgE<gt>

=cut
