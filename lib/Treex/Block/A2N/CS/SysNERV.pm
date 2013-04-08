package Treex::Block::A2N::CS::SysNERV;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);

extends 'Treex::Core::Block';

use Treex::Tool::NamedEnt::Features::Common qw /get_class_from_number $FALLBACK_LEMMA $FALLBACK_TAG/;
use Treex::Tool::NamedEnt::Features::Oneword;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

my $svm;
my $ONEWORD_MODEL = 'data/models/sysnerv/cs/oneword.model';



sub process_start {
    my $modelName = require_file_from_share( $ONEWORD_MODEL, 'A2N::CS::SysNERV' );
    $svm = Algorithm::SVM->new( Model => $modelName);
}


sub process_zone {
    my ($self, $zone) = @_;

    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants({ordered => 1});

    my $n_root;

    if ($zone->has_ntree) {
        die "Not implemented yet";
    } else {
        $n_root = $zone->create_ntree();
    }



    for my $i ( 0 .. $#anodes ) {
        my ( $pprev_anode, $prev_anode, $anode, $next_anode, $nnext_anode ) = @anodes[$i-2..$i+2];

        my %args;

        $args{'act_form'}   = $anode->form;
        $args{'act_lemma'}  = $anode->lemma;
        $args{'act_tag'}    = $anode->tag;
        $args{'prev_lemma'} = defined $prev_anode ? $prev_anode->lemma : $FALLBACK_LEMMA;
        $args{'prev_tag'} = defined $prev_anode ? $prev_anode->tag : $FALLBACK_TAG;
        $args{'pprev_tag'} = defined $pprev_anode ? $pprev_anode->tag : $FALLBACK_TAG;
        $args{'next_lemma'} = defined $next_anode ? $next_anode->lemma : $FALLBACK_LEMMA;

        my @features = extract_oneword_features(%args);

        # Classify oneword entity using SVM classifier
        my $data =  Algorithm::SVM::DataSet->new( Label => 0, Data => \@features );
        my $classification =  $svm->predict($data);

        next if $classification == -1;

        my $class = get_class_from_number($classification);


        # Save entity to tree

        create_entity_node( $n_root, $class, $anode );


    }



    return;
}

sub create_entity_node {
    my ( $n_root, $classification, @m_nodes ) = @_;

#    return if @m_nodes == 0;    # empty entity

    # Check if this entity already exists
#    my @m_ids = sort map{ $_->id } @m_nodes;
#    my $m_ids_label = join $MRF_DELIM, @m_ids;
#    return if exists $entities{$m_ids_label} && $entities{$m_ids_label}->get_attr('ne_type') eq $classification;


    # Create new SCzechN node
    my $n_node = $n_root->create_child;

    # Set classification
    $n_node->set_attr( 'ne_type', $classification );

    # Set a.rf's
    $n_node->set_deref_attr('a.rf', \@m_nodes);

    # Set normalized name
    my $normalized_name;

    foreach my $m_node (@m_nodes) {
        my $act_normalized_name = $m_node->lemma;
        $act_normalized_name =~ s/[-_].*//;
        $normalized_name .= " " . $act_normalized_name;
    }

    $normalized_name =~ s/^ //;
    $n_node->set_attr( 'normalized_name', $normalized_name );

    # Remember this named entity
#    $entities{$m_ids_label} = $n_node;

    # print STDERR ( "Named entity \"$classification\" found: " . $n_node->get_attr('normalized_name') . "\n" );


    return $n_node;
}


1;
