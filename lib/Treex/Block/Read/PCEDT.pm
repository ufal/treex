package Treex::Block::Read::PCEDT;
use Moose;
use Treex::Moose;
extends 'Treex::Block::Read::BaseReader';

use Treex::PML::Factory;
use Treex::PML::Instance;
my $pmldoc_factory = Treex::PML::Factory->new();

my @languages = qw(cs en);
my @layers    = qw(a t p);

has schema_dir => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'directory with pml-schemata for PCEDT data',
    required      => 1,
    trigger       => sub { my ( $self, $dir ) = @_; Treex::PML::AddResourcePath($dir); }
);

sub _copy_attr {
    my ( $pml_node, $treex_node, $old_attr_name, $new_attr_name ) = @_;
    $treex_node->set_attr( $new_attr_name, $pml_node->attr($old_attr_name) );
}

sub _copy_listref_attr {
    my ( $pml_node, $treex_node, $old_attr_name, $new_attr_name ) = @_;
    my $list = $pml_node->attr($old_attr_name);
    return if not ref $list;

    my @list = map { s/^.*#//; $_ } @$list;
    $treex_node->set_attr( $new_attr_name, \@list );
}

sub _convert_ttree {
    my ( $pml_node, $treex_node, $language ) = @_;

    if ( $treex_node->is_root ) {
        my $value = $pml_node->attr('atree.rf');
        $value =~ s/^.*#//;
        $treex_node->set_attr( 'atree.rf', $value );

        foreach my $attr_name ( 'id', 'nodetype' ) {
            _copy_attr( $pml_node, $treex_node, $attr_name, $attr_name );
        }
    }

    else {
        my @scalar_attribs = (
            't_lemma', 'functor', 'id', 'nodetype', 'is_generated', 'subfunctor', 'is_member', 'is_name',
            'is_name_of_person', 'is_dsp_root', 'sentmod', 'tfa', 'is_parenthesis', 'is_state',
            'coref_special'
        );
        my @gram_attribs = (
            'sempos', 'gender', 'number', 'degcmp', 'verbmod', 'deontmod', 'tense', 'aspect', 'resultative',
            'dispmod', 'iterativeness', 'indeftype', 'person', 'numertype', 'politeness', 'negation'
        );
        my @listref_attribs = (
            'compl.rf', 'coref_text.rf', 'coref_gram.rf', 'a/aux.rf'
        );

        _copy_attr( $pml_node, $treex_node, 'deepord', 'ord' );

        foreach my $attr_name ( 'a/lex.rf', 'val_frame.rf' ) {
            my $value = $pml_node->attr($attr_name);
            next if not $value;
            $value =~ s/^.*#//;
            $value = $language . '-v#' . $value if $attr_name eq 'val_frame.rf';
            $treex_node->set_attr( $attr_name, $value );
        }

        foreach my $attr_name (@scalar_attribs) {
            _copy_attr( $pml_node, $treex_node, $attr_name, $attr_name );
        }
        foreach my $attr_name (@listref_attribs) {
            _copy_listref_attr( $pml_node, $treex_node, $attr_name, $attr_name );
        }

        my %gram = ();
        foreach my $attr_name (@gram_attribs) {
            my $value = $pml_node->attr("gram/$attr_name");
            $gram{$attr_name} = $value if $value;
        }
        while ( my ( $attr_name, $value ) = each %gram ) {
            $treex_node->set_attr( "gram/$attr_name", $value );
        }
    }

    foreach my $pml_child ( $pml_node->children ) {
        my $treex_child = $treex_node->create_child;
        _convert_ttree( $pml_child, $treex_child, $language );
    }
}

sub _convert_atree {
    my ( $pml_node, $treex_node ) = @_;

    foreach my $attr_name ( 'id', 'ord' ) {
        _copy_attr( $pml_node, $treex_node, $attr_name, $attr_name );
    }

    if ( not $treex_node->is_root ) {
        _copy_attr( $pml_node, $treex_node, 'm/w/no_space_after', 'no_space_after' );
        foreach my $attr_name ( 'form', 'lemma', 'tag', 'afun' ) {
            _copy_attr( $pml_node, $treex_node, "m/$attr_name", $attr_name );
        }
    }

    foreach my $pml_child ( $pml_node->children ) {
        my $treex_child = $treex_node->create_child;
        _convert_atree( $pml_child, $treex_child );
    }
}

sub next_document {
    my ($self) = @_;

    my $base_filename = $self->next_filename or return;
    $base_filename =~ s/(en|cs)\.[atp]\.gz//;

    my %pmldoc;

    foreach my $language (@languages) {
        foreach my $layer (@layers) {
            next if $layer eq "p" and $language eq "cs";
            my $filename = "${base_filename}$language.${layer}.gz";
            log_info "Loading $filename";
            $pmldoc{$language}{$layer} = $pmldoc_factory->createDocumentFromFile($filename);
        }
    }

    log_fatal "different number of trees in Czech and English t-files"
        if $pmldoc{en}{t}->trees != $pmldoc{cs}{t}->trees;

    my $cs_vallex = $pmldoc{cs}{t}->metaData('refnames')->{'vallex'};
    $cs_vallex = $pmldoc{cs}{t}->metaData('references')->{$cs_vallex};
    my $en_vallex = $pmldoc{en}{t}->metaData('refnames')->{'vallex'};
    $en_vallex = $pmldoc{en}{t}->metaData('references')->{$en_vallex};

    my $document = $self->new_document();    # pre-fills base name, path
    my ( %refnames, %refs );
    $refnames{'vallex'} = $pmldoc_factory->createAlt( [ 'cs-v', 'en-v' ] );
    $refs{'cs-v'}       = $cs_vallex;
    $refs{'en-v'}       = $en_vallex;
    $document->changeMetaData( 'references', \%refs );
    $document->changeMetaData( 'refnames',   \%refnames );

    foreach my $tree_number ( 0 .. ( $pmldoc{en}{t}->trees - 1 ) ) {

        my $bundle = $document->create_bundle;
        foreach my $language (@languages) {
            my $zone = $bundle->create_zone($language);

            my $troot = $zone->create_ttree;
            _convert_ttree( $pmldoc{$language}{t}->tree($tree_number), $troot, $language );

            my $aroot = $zone->create_atree;
            _convert_atree( $pmldoc{$language}{a}->tree($tree_number), $aroot );

            $zone->set_sentence( $aroot->get_sentence_string );

            #            if ($language eq 'en') {
            #                my $proot = $zone->create_ptree;
            #            }
        }
    }

    return $document;
}

1;
