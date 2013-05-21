package Treex::Block::A2N::CS::SysNERV;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);

extends 'Treex::Core::Block';

use Treex::Tool::NamedEnt::Features::Common qw /get_class_from_number $FALLBACK_LEMMA $FALLBACK_TAG/;
use Treex::Tool::NamedEnt::Features::Oneword;
use Treex::Tool::NamedEnt::Features::Twoword;
use Treex::Tool::NamedEnt::Features::Threeword;

use Algorithm::SVM;
use Algorithm::SVM::DataSet;

my %modelFiles;
my %models;

my %containers;
my @entities;

BEGIN {

    log_info("Loading NER models");

    %modelFiles = ( oneword => 'data/models/sysnerv/cs/oneword.model',
                    twoword => 'data/models/sysnerv/cs/twoword.model',
                    threeword  => 'data/models/sysnerv/cs/threeword.model');


    for my $model ( keys %modelFiles ) {
        my $modelName = require_file_from_share( $modelFiles{$model}, 'A2N::CS::SysNERV' );
        $models{$model} = Algorithm::SVM->new( Model => $modelName );
    }

    my $containersFile = require_file_from_share( 'data/models/sysnerv/cs/containers.model', 'A2N::CS::SysNERV' );

    open CONTAINERS, $containersFile or die "Cannot open input file $containersFile";

    my %containerCount;

    log_info("Loading container pattern classificator");

    while (<CONTAINERS>) {
        chomp;
        my ($pattern, $label, $count) = split /\t/;

        if (!defined $containers{$pattern} or $containerCount{$pattern} <= $count) {
            $containers{$pattern} = $label;
            $containerCount{$pattern} = $count;
        }
    }

    close CONTAINERS;

}


sub process_zone {
    my ($self, $zone) = @_;
my %entityRefMap;

    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants({ordered => 1});

    my $n_root;

    if ($zone->has_ntree) {
        die "Not implemented yet";
    } else {
        $n_root = $zone->create_ntree();
    }

    my @validAnodes = grep { $_->form ne '' } @anodes;

    for my $i ( 0 .. $#validAnodes ) {
        my ( $pprev_anode, $prev_anode, $anode, $next_anode, $nnext_anode ) = @validAnodes[$i-2..$i+2];

        my %args;

        $args{'act_form'}   = $anode->form;
        $args{'act_lemma'}  = $anode->lemma;
        $args{'act_tag'}    = $anode->tag;

        $args{'prev_form'} = defined $prev_anode ? $prev_anode->form : $FALLBACK_LEMMA;
        $args{'prev_lemma'} = defined $prev_anode ? $prev_anode->lemma : $FALLBACK_LEMMA;
        $args{'prev_tag'} = defined $prev_anode ? $prev_anode->tag : $FALLBACK_TAG;

        $args{'pprev_form'} = defined $pprev_anode ? $pprev_anode->tag : $FALLBACK_LEMMA;
        $args{'pprev_lemma'} = defined $pprev_anode ? $pprev_anode->tag : $FALLBACK_LEMMA;
        $args{'pprev_tag'} = defined $pprev_anode ? $pprev_anode->tag : $FALLBACK_TAG;

        $args{'next_form'} = defined $next_anode ? $next_anode->form : $FALLBACK_LEMMA;
        $args{'next_lemma'} = defined $next_anode ? $next_anode->lemma : $FALLBACK_LEMMA;
        $args{'next_tag'} = defined $next_anode ? $next_anode->tag : $FALLBACK_TAG;

        $args{'nnext_form'} = defined $nnext_anode ? $nnext_anode->form : $FALLBACK_LEMMA;
        $args{'nnext_lemma'} = defined $nnext_anode ? $nnext_anode->lemma : $FALLBACK_LEMMA;
        $args{'nnext_tag'} = defined $nnext_anode ? $nnext_anode->tag : $FALLBACK_TAG;

	$args{'namedents'} = \@entities; # wow, tohle by dokonce mělo
                                         # zajistit, že bude jiná
                                         # hodnota v extract_twoword
                                         # než v oneword, pokud tam
                                         # bylo pushnuto

        my (@features, $data, $classification, $label, $n_node);

        #### ONEWORD ####

        @features = extract_oneword_features(%args);

        $data =  Algorithm::SVM::DataSet->new( Label => 0, Data => \@features );
        $classification =  $models{oneword}->predict($data);

        $label = $classification == -1 ? 0 : get_class_from_number($classification);
        create_entity_node( $n_root, $label, $anode ) unless $classification == -1;

        $entities[$i] = $label;

        #### TWOWORD ####
        if ($i > 1) {

            @features = extract_twoword_features(%args);

            $data = Algorithm::SVM::DataSet->new( Label => 0, Data => \@features);
            $classification = $models{twoword}->predict($data);

            unless ($classification == -1) {
                $label = get_class_from_number($classification);
                create_entity_node( $n_root, $label, $prev_anode, $anode );

                $entities[$i-1] = $label;
                $entities[$i] = $label;
            }
        }

        #### THREEWORD ####
        if ($i > 2) {

            @features = extract_threeword_features(%args);

            $data = Algorithm::SVM::DataSet->new( Label => 0, Data => \@features);
            $classification = $models{threeword}->predict($data);

            unless ($classification == -1) {
                $label = get_class_from_number($classification);
                create_entity_node( $n_root, $label, $pprev_anode, $prev_anode, $anode );

                $entities[$i-2] = $label;
                $entities[$i-1] = $label;
                $entities[$i] = $label;
            }
        }

	for my $j ( 0 .. $i-1) {
	    my $pattern = @entities[$j..$i];
	    my $container = $containers{$pattern};

	    if (defined $container and $container ne '0') {

		#TODO zed jsme skoncili
	#	create_entity_container_node($n_root, $container, \@anodes[$j..$i]);
	    }

	}

    }
}

sub create_entity_node {
    my ( $n_root, $classification, @a_nodes ) = @_;

    #    return if @a_nodes == 0;    # empty entity

    # Check if this entity already exists
    #    my @a_ids = sort map{ $_->id } @a_nodes;
    #    my $a_ids_label = join $MRF_DELIM, @a_ids;
    #    return if exists $entities{$a_ids_label} && $entities{$a_ids_label}->get_attr('ne_type') eq $classification;



    # Create new SCzechN node
    my $n_node = $n_root->create_child;

    # Set classification
    $n_node->set_attr( 'ne_type', $classification );

    # Set a.rf's
    $n_node->set_deref_attr('a.rf', \@a_nodes);

    # Set normalized name
    my $normalized_name;

    foreach my $a_node (@a_nodes) {
        my $act_normalized_name = $a_node->lemma;
        $act_normalized_name =~ s/[-_].*//;
        $normalized_name .= " " . $act_normalized_name;
    }

    $normalized_name =~ s/^ //;
    $n_node->set_attr( 'normalized_name', $normalized_name );

    # Remember this named entity
    #    $entities{$a_ids_label} = $n_node;

    # print STDERR ( "Named entity \"$classification\" found: " . $n_node->get_attr('normalized_name') . "\n" );


    return $n_node;
}

1;

__END__

sub create_entity_container_node {
    my ( $n_root, $classification, $anodesRef ) = @_;

    my @anodes = @$anodesRef;

    die "Not implemented yet";

    # Check if this container already exists
#    my $m_ids_label = join $MRF_DELIM, sort @{$m_ids_ref};
#    return if exists $entities{$m_ids_label} && $entities{$m_ids_label}->get_attr('ne_type') eq $classification;


    # Get corresponding n-nodes
    my @n_nodes = map $entities{$_}, @{$m_ids_ref};

    # Create new SCzechN node
    my $n_node = $n_root->create_child;

    # Set classification
    $n_node->set_attr('ne_type', $classification);

    # Set m.rf's
    $n_node->set_deref_attr('m.rf', $m_nodes_ref );

    # Set normalized name
    my $normalized_name;
    foreach my $n (@n_nodes) {
        $normalized_name .= " ". $n->get_attr('normalized_name') if $n->get_attr('normalized_name');
    }
    $n_node->set_attr('normalized_name', $normalized_name);

    # Remember this container
    $entities{$m_ids_label} = $n_node;

    #    print STDERR ( "Named entity container \"$classification\" found: ". $n_node->get_attr('normalized_name')."\n");
    return $n_node;
}


1;
