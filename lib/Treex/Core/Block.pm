package Treex::Core::Block;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use Digest::MD5 qw(md5_hex);
use Storable;
use Time::HiRes;
use App::whichpm 'which_pm';
use Readonly;
use List::MoreUtils qw(uniq);

has selector => ( is => 'ro', isa => 'Str', default => '' );
has language => ( is => 'ro', isa => 'Str', default => 'all' );

has scenario => (
    is       => 'ro',
    isa      => 'Treex::Core::Scenario',
    writer   => '_set_scenario',
    weak_ref => 1,
);

has select_bundles => (
    is            => 'ro',
    default       => 0,
    documentation => 'apply process_bundle only on the specified bundles,'
        . ' e.g. "1-4,6,8-12". The default is 0 which means all bundles. Useful for debugging.',
);

has if_missing_zone => (
    is            => 'ro',
    isa           => enum( [qw(fatal warn ignore create)] ),
    default       => 'fatal',
    documentation => 'What to do if process_zone is to be called on a zone'
        . ' (specified by parameters language and selector) that is missing in a given bundle?',
);

has if_missing_tree => (
    is            => 'ro',
    isa           => enum( [qw(fatal warn ignore create)] ),
    default       => 'fatal',
    documentation => 'What to do if process_[atnp]tree is to be called on a tree'
        . ' that is missing in a given zone?',
);

has if_missing_bundles => (
    is            => 'ro',
    isa           => enum( [qw(fatal warn ignore)] ),
    default       => 'fatal',
    documentation => 'What to do if process_document is to be called on a document'
        . ' with no bundles?',
);



has report_progress => (
    is            => 'ro',
    isa           => 'Str',
    default       => 0,
    documentation => 'Report which bundle (TODO: zone,tree,node) is being processed via log_info. Useful for debugging.',
);

has [qw(_is_bundle_selected _is_language_selected _is_selector_selected)] => ( is => 'rw' );

has _hash => ( is => 'rw', isa => 'Str' );

has is_started => ( is => 'ro', isa => 'Bool', writer => '_set_is_started', default => 0 );

Readonly our $DOCUMENT_PROCESSED  => 1;
Readonly our $DOCUMENT_FROM_CACHE => 2;


# For load_other_block() and get_or_load_other_block()
# TODO this could also be in Scenario instead of Block...

# new other block of same name replaces old one here
has _loaded_other_blocks       => ( is => 'rw', isa => 'HashRef',  default => sub { {} } ); 
# all loaded other blocks, no replacing
has _loaded_other_blocks_array => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } ); 

sub zone_label {
    my ($self) = @_;
    my $label = $self->language or return;
    if ( defined $self->selector && $self->selector ne '' ) {
        $label .= '_' . $self->selector;
    }
    return $label;
}

# TODO
# has robust => ( is=> 'ro', isa=>'Bool', default=>0,
#                 documentation=>'no fatal errors in robust mode');

sub BUILD {
    my $self = shift;

    if ( $self->select_bundles ) {
        log_fatal 'select_bundles=' . $self->select_bundles . ' does not match /^\d+(-\d+)?(,\d+(-\d+)?)*$/'
            if $self->select_bundles !~ /^\d+(-\d+)?(,\d+(-\d+)?)*$/;
        my %selected;
        foreach my $span ( split /,/, $self->select_bundles ) {
            if ( $span =~ /(\d+)-(\d+)/ ) {
                @selected{ $1 .. $2 } = ( $1 .. $2 );
            }
            else {
                $selected{$span} = 1;
            }
        }
        $self->_set_is_bundle_selected( \%selected );
    }

    if ( $self->language ne 'all' ) {
        my @codes = split /,/, $self->language;
        my %selected;
        for my $code (@codes) {
            log_fatal "'$code' is not a valid ISO 639-1 language code"
                if !Treex::Core::Types::is_lang_code($code);
            $selected{$code} = 1;
        }
        $self->_set_is_language_selected( \%selected );
    }

    if ( $self->selector ne 'all' ) {
        if ( $self->selector eq '' ) {
            $self->_set_is_selector_selected( { q{} => 1 } );
        }
        else {
            my @selectors = split /,/, $self->selector;
            my %selected;
            for my $selector (@selectors) {
                log_fatal "'$selector' is not a valid selector name"
                    if $selector !~ /^[a-z\d]*$/i;
                $selected{$selector} = 1;
            }
            $self->_set_is_selector_selected( \%selected );
        }
    }

    return;
}

sub _compute_hash {
    my $self = shift;

    my $md5 = Digest::MD5->new();

    # compute block parameters hash
    my $params_str = "";
    map {
        $params_str .= $_ . "=" . $self->{$_};

        # log_warn("\t\t" . $_ . "=" . $self->{$_} . " - " . ref($self->{$_}));
        }
        sort    # in canonical form
        grep { !ref( $self->{$_} ) }       # no references
        grep { defined( $self->{$_} ) }    # value has to be defined
        grep { !/(scenario|block)/ }
        keys %{$self};
        
    # Digest::MD5 cannot handle Unicode strings (it dies with "Wide character in subroutine entry")
    use Encode;
    $md5->add(Encode::encode_utf8($params_str));

    # compute block source code hash
    my ( $block_filename, $block_version ) = which_pm( $self->get_block_name() );
    open( my $block_fh, "<", $block_filename ) or log_fatal("Can't open '$block_filename': $!");
    binmode($block_fh);
    $md5->addfile($block_fh);
    close($block_fh);

    $self->_set_hash( $md5->hexdigest );

    return;
}

sub get_hash {
    my $self = shift;
    if (!$self->_hash){
        $self->_compute_hash();
    }
    return $self->_hash;
}

sub require_files_from_share {
    my ( $self, @rel_paths ) = @_;
    my $my_name = 'the block ' . $self->get_block_name();
    return map {
        log_info $self->get_block_name() . " requires file " . $_;
        Treex::Core::Resource::require_file_from_share( $_, $my_name )
    } @rel_paths;
}

sub get_required_share_files {
    my ($self) = @_;

    # By default there are no required share files.
    # The purpose of this method is to be overriden if needed.
    return ();
}

sub process_document {
    my $self = shift;
    my ($document) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Document' },
    );

    if ( !$document->get_bundles() && $self->if_missing_bundles =~ /fatal|warn/){
        my $message = "There are no bundles in the document and block " . $self->get_block_name() .
            " doesn't override the method process_document. You can use prepend 'Util::SetGlobal if_missing_bundles=ignore' to allow processing empty documents. ";
        log_fatal($message) if $self->if_missing_bundles eq 'fatal';
        log_warn($message);
    }

    my $bundleNo = 1;
    foreach my $bundle ( $document->get_bundles() ) {
        if ( !$self->select_bundles || $self->_is_bundle_selected->{$bundleNo} ) {
            $self->process_bundle( $bundle, $bundleNo );
        }
        $bundleNo++;
    }
    return 1;
}

sub _apply_function_on_each_zone {
    my ($self, $doc, $function, @function_params) = @_;
    my %zones;

    # When using "all", we must collect the zones used in the whole document.
    if ($self->language eq 'all' || $self->selector eq 'all'){
        foreach my $bundle ($doc->get_bundles){
            foreach my $zone ($bundle->get_all_zones()){
                $zones{$zone->get_label()} = 1;
            }
        }
    }
    # Otherwise, we can make a Cartesian product of lang(uage)s and sel(ector)s
    else {
        foreach my $lang (keys %{$self->_is_language_selected}){
            foreach my $sel (keys %{$self->_is_selector_selected}){
                $zones{$lang . '_' . $sel} = 1;
            }
        }
    }

    my $orig_language = $self->language;
    my $orig_selector = $self->selector;
    foreach my $label (keys %zones){
        my ($lang, $sel) = split /_/, $label;

        # pretend this block was called with only this one language and selector
        $self->{language} = $lang;
        $self->{selector} = $sel;
        $function->(@function_params);
    }
    $self->{language} = $orig_language;
    $self->{selector} = $orig_selector;
    return;
}

sub process_bundle {
    my ( $self, $bundle, $bundleNo ) = @_;
    if ($self->report_progress){
        log_info "Processing bundle $bundleNo";
    }

    my @zones = $bundle->get_all_zones();

    if ($self->if_missing_zone eq 'create') {
        my (@langs, @sels);
        if ($self->language eq 'all') {
            @langs = uniq map{$_->language} @zones;
        } else {
            @langs = keys %{$self->_is_language_selected};
        }
        if ($self->selector eq 'all') {
            @sels = uniq map{$_->selector} @zones;
        } else {
            @sels = keys %{$self->_is_selector_selected};
        }
        
        # Cartesian product of lang(uage)s and sel(ector)s
        @zones = map {my $l = $_; map{$bundle->get_or_create_zone($l, $_)} @sels} @langs;
    } else {
        @zones = $self->get_selected_zones(@zones);
    }
    
    if (!@zones && $self->if_missing_zone =~ /fatal|warn/) {
        my $message = "No zone (language="
            . $self->language
            . ", selector="
            . $self->selector
            . ") was found in a bundle and block " . $self->get_block_name()
            . " doesn't override the method process_bundle";
        log_fatal($message) if $self->if_missing_zone eq 'fatal';
        log_warn($message);
    }

    foreach my $zone (@zones) {
        $self->process_zone( $zone, $bundleNo );
    }
    return;
}

sub get_selected_zones {
    my ( $self, @zones ) = @_;
    if ( $self->language ne 'all') {
        @zones = grep { $self->_is_language_selected->{ $_->language } } @zones;
    }
    if ( $self->selector ne 'all') {
        @zones = grep { $self->_is_selector_selected->{ $_->selector } } @zones;
    }

    return @zones;
}

sub _try_process_layer {
    my ( $self, $zone, $layer, $bundleNo ) = @_;
    my $meta = $self->meta;

    if ( my $m = $meta->find_method_by_name("process_${layer}tree") ) {
        if (!$zone->has_tree($layer)){
            if ($self->if_missing_tree eq 'create'){
                $zone->create_tree($layer);
            } else {
                return 0;
            }
        }
        
        #$self->process_atree($tree, $bundleNo);
        $m->execute( $self, $zone->get_tree($layer), $bundleNo );
        return 1;
    }

    if ( my $m = $meta->find_method_by_name("process_${layer}node") ) {
        if (!$zone->has_tree($layer)){
            if ($self->if_missing_tree eq 'create'){
                $zone->create_tree($layer);
            } else {
                return 0;
            }
        }
        my $tree = $zone->get_tree($layer);
    
        # process_ptree should be executed also on the root node (usually the S phrase)
        my @opts = $layer eq 'p' ? ( { add_self => 1 } ) : ();
        foreach my $node ( $tree->get_descendants(@opts) ) {
            # Skip nodes deleted by previous process_Xnode() call.
            next if ref $node eq 'Treex::Core::Node::Deleted';

            #$self->process_anode($node, $bundleNo);
            $m->execute( $self, $node, $bundleNo );
        }
        return 1;
    }

    return 0;
}

sub process_zone {
    my ( $self, $zone, $bundleNo ) = @_;
    my $overriden = 0;

    for my $layer (qw(a t n p)) {
        if ($self->_try_process_layer( $zone, $layer, $bundleNo )){
            $overriden++;
        }
    }
    
    if (!$overriden && $self->if_missing_tree =~ /fatal|warn/){
        my $message = "At least one of the methods /process_(document|bundle|zone|[atnp](tree|node))/ "
            . "must be overriden and the corresponding [atnp] trees must be present in bundles.\n"
            . "The zone '" . $zone->get_label() . "' contains trees ( "
            . ( join ',', map { $_->get_layer() } $zone->get_all_trees() ) . ").";
        log_fatal($message) if $self->if_missing_tree eq 'fatal';
        log_warn($message);
    }

    return;
}

sub process_start {
    my ($self) = @_;

    $self->require_files_from_share( $self->get_required_share_files() );

    return;
}

after 'process_start' => sub {
    my ($self) = @_;
    $self->_set_is_started(1);
};

sub process_end {
    my ($self) = @_;

    # default implementation is empty, but can be overriden
    return;
}

after 'process_end' => sub {
    my ($self) = @_;
    foreach my $other_block (@{$self->_loaded_other_blocks_array}) {
        if ( $other_block->is_started ) {
            $other_block->process_end();
        }
    }
    $self->_set_is_started(0);
};

sub get_block_name {
    my $self = shift;
    return ref($self);
}

sub load_other_block {
    my ($self, $other_block_name, $params_hash_ref) = @_;

    my $other_block_full_name = "Treex::Block::$other_block_name";

    # CONSTRUCT PARAMETERS HASH
    # global params (TODO: do that?)
    my %params = %{$self->scenario->_global_params};
    # overridden by selected (TODO: all?) block params
    $params{language} = $self->language;
    $params{selector} = $self->selector;
    $params{scenario} = $self->scenario;
    # overridden by locally set params
    @params{ keys %$params_hash_ref } = values %$params_hash_ref;

    # CREATE IT and start it
    eval "use $other_block_full_name; 1;" or
    log_fatal "Treex::Core::Block->get_other_block: " .
    "Can't use block $other_block_name!\n$@\n";
    my $other_block;
    eval {
        $other_block = $other_block_full_name->new( \%params );
        1;
    } or log_fatal "Treex::Core::Block->get_other_block: " .
    "Can't initialize block $other_block_name!\n$@\n";
    $other_block->process_start();

    # this may replace older block with same name
    $self->_loaded_other_blocks->{$other_block_name} = $other_block;
    # this not
    push @{$self->_loaded_other_blocks_array}, $other_block;

    return $other_block;
}

sub get_or_load_other_block {
    my ($self, $other_block_name, $params_hash_ref) = @_;

    my $other_block =
        exists ($self->_loaded_other_blocks->{$other_block_name})
        ?
        $self->_loaded_other_blocks->{$other_block_name}
        :
        $self->load_other_block($other_block_name, $params_hash_ref)
    ;

    return $other_block;
}

1;

__END__

=for Pod::Coverage BUILD build_language

=encoding utf-8

=head1 NAME

Treex::Core::Block - the basic data-processing unit in the Treex framework

=head1 SYNOPSIS

 package Treex::Block::My::Block;
 use Moose;
 use Treex::Core::Common;
 extends 'Treex::Core::Block';

 sub process_bundle {
    my ( $self, $bundle) = @_;

    # bundle processing

 }

=head1 DESCRIPTION

C<Treex::Core::Block> is a base class serving as a common ancestor of
all Treex blocks.
C<Treex::Core::Block> can't be used directly in any scenario.
Use it's descendants which implement one of the methods
C<process_document()>, C<process_bundle()>, C<process_zone()>,
C<process_[atnp]tree()> or C<process_[atnp]node()>.


=head1 CONSTRUCTOR

=over 4

=item my $block = Treex::Block::My::Block->new();

Instance of a block derived from C<Treex::Core::Block> can be created
by the constructor (optionally, a reference to a hash of block parameters
can be specified as the constructor's argument, see L</BLOCK PARAMETRIZATION>).
However, it is not likely to appear in your code since block initialization
is usually invoked automatically when initializing a scenario.

=back

=head1 METHODS FOR BLOCK EXECUTION

You must override one of the following methods:

=over 4

=item $block->process_document($document);

Applies the block instance on the given instance of
L<Treex::Core::Document>. The default implementation
iterates over all bundles in a document and calls C<process_bundle()>. So in
most cases you don't need to override this method.

=item $block->process_bundle($bundle);

Applies the block instance on the given bundle
(L<Treex::Core::Bundle>).

=item $block->process_zone($zone);

Applies the block instance on the given bundle zone
(L<Treex::Core::BundleZone>). Unlike
C<process_document> and C<process_bundle>, C<process_zone> requires block
attribute C<language> (and possibly also C<selector>) to be specified.

=item $block->process_I<X>tree($tree);

Here I<X> stands for a,t,n or p.
This method is executed on the root node of a tree on a given layer (a,t,n,p).

=item $block->process_I<X>node($node);

Here I<X> stands for a,t,n or p.
This method is executed on the every node of a tree on a given layer (a,t,n,p).
Note that for layers a, t, and n, this method is not executed on the root node
(because the root node is just a "technical" root without the attributes of regular nodes).
However, C<process_pnode> is executed also on the root node
(because its a regular non-terminal node with a phrase attribute, usually C<S>).

=back

=head2 $block->process_start();

This method is called before all documents are processed.
This method is responsible for loading required models.

=head2 $block->process_end();

This method is called after all documents are processed.
The default implementation is empty, but derived classes can override it
to e.g. print some final summaries, statistics etc.
Overriding this method is preferable to both
standard Perl END blocks (where you cannot access C<$self> and instance attributes),
and DEMOLISH (which is not called in some cases, e.g. C<treex --watch>).



=head1 BLOCK PARAMETRIZATION

=over 4

=item my $block = BlockGroup::My_Block->new({$name1=>$value1,$name2=>$value2...});

Block instances can be parametrized by a hash containing parameter name/value
pairs.

=item my $param_value = $block->get_parameter($param_name);

Parameter values used in block construction can
be revealed by C<get_parameter> method (but cannot be changed).

=back

=head1 MISCEL

=over 4

=item my $langcode_selector = $block->zone_label();

=item my $block_name = $block->get_block_name();

It returns the name of the block module.

=item my @needed_files = $block->get_required_share_files();

If a block requires some files to be present in the shared part of Treex,
their list (with relative paths starting in
L<Treex::Core::Config-E<gt>share_dir|Treex::Core::Config/share_dir>) can be
specified by redefining by this method. By default, an empty list is returned.
Presence of the files is automatically checked in the block constructor. If
some of the required file is missing, the constructor tries to download it
from L<http://ufallab.ms.mff.cuni.cz>.

This method should be used especially for downloading statistical models,
but not for installed tools or libraries.

 sub get_required_share_files {
     my $self = shift;
     return (
         'data/models/mytool/'.$self->language.'/features.gz',
         'data/models/mytool/'.$self->language.'/weights.tsv',
     );
 }

=item require_files_from_share()

This method checks existence of files given as parameters, it tries to download them if they are not present

=back

=head1 SEE ALSO

L<Treex::Core::Node>,
L<Treex::Core::Bundle>,
L<Treex::Core::Document>,
L<Treex::Core::Scenario>,

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
