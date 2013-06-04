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

# This array serves as entity pattern of a sentence. This is used when
# recognizing containers
my @entityPattern;

# co se ukládá sem?
my %entities;


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

sub read_named_entities {
    my ($n_node) = @_;
    return if not $n_node;

    my @a_ids;

    if (! $n_node->get_children) {
        # leaf node

        my $a_nodes_ref = $n_node->get_deref_attr('a.rf');

        if ($a_nodes_ref) {

            @a_ids = sort map { $_->id } @{$a_nodes_ref};
            my $aIDString = join " ", @a_ids;

            if (!defined $entities{$aIDString}) {
                $entities{$aIDString} = [];
            }

            push @{$entities{$aIDString}}, $n_node if $n_node->get_attr("ne_type");
        }

    } else {
        # internal node

        my @children = $n_node->get_children;

        @a_ids = sort map { read_named_entities($_) } @children;

        my $aIDString = join " ", @a_ids;

        if (!defined $entities{$aIDString}) {
            $entities{$aIDString} = [];
        }

        push @{$entities{$aIDString}}, $n_node if $n_node->get_attr('ne_type');
    }

    return @a_ids;
}



sub process_zone {
    my ($self, $zone) = @_;
    my %entityRefMap;

    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants({ordered => 1});

    my $n_root;

    if ($zone->has_ntree) {
        $n_root = $zone->get_ntree;
        read_named_entities($n_root);
    } else {
        $n_root = $zone->create_ntree();
    }

    my @validAnodes = grep { $_->form !~m/^\s*$/ } @anodes;

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

        $args{'namedents'} = \@entityPattern; # wow, tohle by dokonce mělo
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

        if ($classification != -1) {
            #create n-node and store it in anode's entity list
            my $anodeIDString = $anode->id;

            unless (defined $entities{ $anodeIDString } and grep { $_->get_attr('ne_type') eq $label } @{$entities{ $anodeIDString }}) {
                $n_node = create_entity_node( $n_root, $label, $anode )
            }


            if (!defined $entities{ $anodeIDString } ) {
                $entities{ $anodeIDString } = [];
            }

            push @{$entities{$anodeIDString}}, $n_node;

        }

        $entityPattern[$i] = $label;

        #### TWOWORD ####
        if ($i > 1) {

            @features = extract_twoword_features(%args);

            $data = Algorithm::SVM::DataSet->new( Label => 0, Data => \@features);
            $classification = $models{twoword}->predict($data);

            unless ($classification == -1) {
                $label = get_class_from_number($classification);

                my $anodeIDString = join " ", map { $_->id } ($prev_anode, $anode);

                $n_node = create_entity_node( $n_root, $label, $prev_anode, $anode )
                    unless defined $entities{ $anodeIDString } and grep { $_->get_attr('ne_type') eq $label } @{$entities{ $anodeIDString } };

                if (!defined $entities{ $anodeIDString } ) {
                    $entities{ $anodeIDString } = [];
                }

                push @{$entities{ $anodeIDString }}, $n_node;

                $entityPattern[$i-1] = $label;
                $entityPattern[$i] = $label;
            }
        }

        #### THREEWORD ####
        if ($i > 2) {

            @features = extract_threeword_features(%args);

            $data = Algorithm::SVM::DataSet->new( Label => 0, Data => \@features);
            $classification = $models{threeword}->predict($data);

            unless ($classification == -1) {
                $label = get_class_from_number($classification);

                my $anodeIDString = join " ", map {$_->id}  ($pprev_anode, $prev_anode, $anode);

                $n_node = create_entity_node( $n_root, $label, $pprev_anode, $prev_anode, $anode )
                    unless defined $entities{ $anodeIDString } and grep { $_->get_attr('ne_type') eq $label } @{$entities{ $anodeIDString } };

                if (!defined $entities{ $anodeIDString } ) {
                    $entities{ $anodeIDString } = [];
                }

                push @{$entities{$anodeIDString}}, $n_node;

                $entityPattern[$i-2] = $label;
                $entityPattern[$i-1] = $label;
                $entityPattern[$i] = $label;
            }
        }


        #### CONTAINERS ####
        for my $j ( 0 .. $i-1) {
            my $pattern = join " ", @entityPattern[$j..$i];
            my $container = $containers{$pattern};

            if (defined $container and $container ne '0') {

                my $anodeIDString = join " ", map {$_->id} @anodes[$j..$i];

                my $n_cont = create_entity_container_node($n_root, $container, @anodes[$j..$i])
                    unless defined $entities{ $anodeIDString } and grep {$_->get_attr('ne_type') eq $label } @{$entities{$anodeIDString}};

                if (!defined $entities{$anodeIDString} ) {
                    $entities{$anodeIDString} = [];
                }

                push @{$entities{$anodeIDString}}, $n_cont;

		last; # (we dont want nested containers)
            }

        }
    }
}

sub create_entity_node {
    my ( $n_root, $classification, @a_nodes ) = @_;

    # Create new N-node
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

    return $n_node;
}


sub create_entity_container_node {
    my ( $n_root, $classification, @anodes ) = @_;

    # Create new SCzechN node
    my $n_node = $n_root->create_child;

    # Set classification
    $n_node->set_attr('ne_type', $classification);

    # Set a.rf's
    $n_node->set_deref_attr('a.rf', \@anodes );

    # Set normalized name
    my @normalized_chunks;

    for my $i (0..$#anodes) {

        my $lemma = $anodes[$i]->lemma;

        $lemma =~ s/[-_].*//;
        push @normalized_chunks, $lemma;
    }

    my $normalized_name = join " ", @normalized_chunks;
    $n_node->set_attr('normalized_name', $normalized_name);

    return $n_node;
}


1;
