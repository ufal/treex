package Treex::Core::Block;
use Moose;
use Treex::Moose;
use LWP::Simple;

has selector => ( is => 'ro', isa => 'Selector', default => '',);
has language => ( is => 'ro', isa => 'LangCode',);
has scenario => ( is => 'ro', isa => 'Treex::Core::Scenario',
                  writer => '_set_scenario', weak_ref => 1,);

# TODO
# has robust => ( is=> 'ro', isa=>'Bool', default=>0,
#                 documentation=>'no fatal errors in robust mode');

sub process_document {
    my ( $self, $document ) = @_;
    if (!$document->get_bundles()){
        log_fatal "There are no bundles in the document and block ". ref($self) .
        " doesn't override the method process_document";
    }
    foreach my $bundle ( $document->get_bundles() ) {
        $self->process_bundle($bundle);
    }
    return 1;
}

sub process_bundle {
    my ($self, $bundle) = @_;
    log_fatal "Parameter language was not set and block ". ref($self)
        . " doesn't override the method process_bundle" if !$self->language;
    my $zone = $bundle->get_zone($self->language, $self->selector);
    log_fatal("Zone (lang=".$self->language.", selector=". $self->selector
        . ") was not found in a bundle and block ". ref($self)
        . " doesn't override the method process_bundle")
        if !$zone;
    return $self->process_zone($zone);
}

sub process_zone {
    my ($self, $zone) = @_;

    log_fatal("process_zone not overriden and all process_?tree return false") if not
        ( ( $zone->has_tree('a') && $self->process_atree($zone->get_a_tree) )
        or ( $zone->has_tree('t') && $self->process_ttree($zone->get_t_tree) )
        or ( $zone->has_tree('n') && $self->process_ntree($zone->get_n_tree) )
        or ( $zone->has_tree('p') && $self->process_ptree($zone->get_p_tree) ) ); 
}

sub process_atree {
    my ($self, $tree) = @_;
    foreach my $node ($tree->get_descendants()){
        $self->process_anode($node);
    }
    return 1;
}

sub process_anode {
    log_fatal "process_anode() is not (and could not be) implemented"
        . " in the abstract class Treex::Core::Block !";   
}

sub process_ttree {
    my ($self, $tree) = @_;
    foreach my $node ($tree->get_descendants()){
        $self->process_tnode($node);
    }
    return 1;
}

sub process_tnode {
    log_fatal "process_tnode() is not (and could not be) implemented"
        . " in the abstract class Treex::Core::Block !";   
}

sub process_ntree {
    my ($self, $tree) = @_;
    foreach my $node ($tree->get_descendants()){
        $self->process_nnode($node);
    }
    return 1;
}

sub process_nnode {
    log_fatal "process_nnode() is not (and could not be) implemented"
        . " in the abstract class Treex::Core::Block !";   
}

sub process_ptree {
    my ($self, $tree) = @_;
    foreach my $node ($tree->get_descendants()){
        $self->process_pnode($node);
    }
    return 1;
}

sub process_pnode {
    log_fatal "process_pnode() is not (and could not be) implemented"
        . " in the abstract class Treex::Core::Block !";   
}

sub get_block_name {
    my ($self) = @_;
    return ref($self);
}

sub require_file_from_share {

    my ( $self, $rel_path_to_file ) = @_;

    my $file = Treex::Core::Config::share_dir() . $rel_path_to_file;

    if ( not -e $file ) {
        log_info("Shared file '$rel_path_to_file' is missing by the block " . $self->get_block_name() . ".");

        my $url = "http://ufallab.ms.mff.cuni.cz/tectomt/share/$rel_path_to_file";
        log_info("Trying to download $url");

        # first ensure that the directory exists
        my $directory = $file;
        $directory =~ s/[^\/]*$//;
        File::Path::mkpath($directory);

        # download the file using LWP::Simple
        my $response_code = getstore( $url, $file );
        if ( $response_code == 200 ) {
            log_info("Successfully downloaded to $file");
        }
        elsif ( $response_code == 404 ) {
            log_fatal("The file $url doesn't exsist. Can't run the block " . $self->get_block_name() . ".");
        }
        else {
            log_fatal("Error when trying to download $url and to store it as $file ($response_code).");
        }
    }
    return $file;
}


sub get_required_share_files {
    return ();
}

1;



__END__

=head1 NAME

TectoMT::Block !!!!!!!!!!!!! needs to be updated

=head1 SYNOPSIS

 package BlockGroup::My_Block;
 
 use strict; use warnings; use utf8;
 
 use base qw(TectoMT::Block);
 
 sub process_bundle {
    my ($self, $bundle) = @_;
    
    # processing
    
 }

=head1 DESCRIPTION

C<TectoMT::Block> is a base class serving as a common ancestor of
all TectoMT blocks.
C<TectoMT::Block> can't be used directly in any scenario.
Use it's descendants which implement method C<process_bundle()>
(or C<process_document()>) instead.

=head1 CONSTRUCTOR

=over 4

=item my $block = BlockGroup::My_Block->new();

Instance of a block derived from TectoMT::Block can be created
by the constructor (optionally, a reference to a hash of block parameters
can be specified as the constructor's argument, see BLOCK PARAMETRIZATION).
However, it is not likely to appear in your code since block initialization
is usually invoked automatically when initializing a scenario.

=back

=head1 METHODS FOR BLOCK EXECUTION

=over 4

=item $block->process_document($document);

Applies the block instance on the given instance of C<TectoMT::Document>.
The default implementation iterates over all bundles in a document
and calls C<process_bundle()>.
So in most cases you don't need to override this method.

=item $block->process_bundle($bundle);

Applies the block instance on the given bundle (C<TectoMT::Bundle>).
This is the method you must implement to make your block working
(unless you override C<process_document()>).

=item $block->process_stream($stream);

Applies the block instance on the given stream (C<TectoMT::Bundle>).


=back

=head1 BLOCK PARAMETRIZATION

=over 4

=item my $block = BlockGroup::My_Block->new({$name1=>$value1,$name2=>$value2...});

Block instances can be parametrized by a hash containing parameter name/value
pairs.

=item my $param_value = $block->get_parameter($param_name);

Parameter values used in block construction can
be revealed by get_parameter method (but cannot be changed).

=back

=head1 MISCEL

=over 4

=item my $block_name = $block->get_block_name();

It returns the name of the block module.

=item my @needed_files = $block->get_required_share_files();

If a block requires some files to be present in the shared part
of TectoMT, their list (with relative paths starting in $TMT_ROOT/share/) can be specified
by redefining by this method. By default, an empty list is returned. Presence
of the files is automatically checked in the block constructor. If some of
the required file is missing, the constructor tries to download it
from http://ufallab.ms.mff.cuni.cz.

This method should be used especially for downloading statistical models,
but not for installed tools or libraries.

 sub get_required_share_files {
     my $self = shift;
     return (
         'data/models/mytool/'.$self->language.'/features.gz',
         'data/models/mytool/'.$self->language.'/weights.tsv',
     );
 }


=back

=head1 SEE ALSO

L<TectoMT::Node|TectoMT::Node>,
L<TectoMT::Bundle|TectoMT::Bundle>,
L<TectoMT::Document|TectoMT::Document>,
L<TectoMT::Scenario|TectoMT::Scenario>,

=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright 2006-2011 Zdenek Zabokrtsky, Martin Popel
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

