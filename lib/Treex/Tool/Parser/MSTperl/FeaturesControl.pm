package Treex::Tool::Parser::MSTperl::FeaturesControl;

use Moose;
use autodie;
use Carp;

use Treex::Tool::Parser::MSTperl::ModelAdditional;

# TODO dynamic features

has 'config' => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
    weak_ref => '1',
);

# FEATURES

has 'feature_count' => (
    is  => 'rw',
    isa => 'Int',
);

has 'feature_codes_from_config' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);

has 'feature_codes' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);

has 'feature_codes_hash' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

has 'feature_indexes' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

# for each feature contains (a reference to) an array
# which cointains all its subfeature indexes
has 'feature_simple_features_indexes' => (
    is      => 'rw',
    isa     => 'ArrayRef[ArrayRef[Int]]',
    default => sub { [] },
);

# features containing array simple features
has 'array_features' => (
    is      => 'rw',
    isa     => 'HashRef[Int]',
    default => sub { {} },
);

# features containing dynamic simple features
has 'dynamic_features' => (
    is      => 'rw',
    isa     => 'HashRef[Int]',
    default => sub { {} },
);

# SIMPLE FEATURES

has 'simple_feature_count' => (
    is  => 'rw',
    isa => 'Int',
);

has 'simple_feature_codes' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);

has 'simple_feature_codes_hash' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

has 'simple_feature_indexes' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

has 'simple_feature_subs' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has 'simple_feature_sub_arguments' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

# simple features that return an array of values
has 'array_simple_features' => (
    is      => 'rw',
    isa     => 'HashRef[Int]',
    default => sub { {} },
);

# simple features that must be always recomputed
# because their value cannot be always computed from input data
# (for labeller - parent's label, brother's label etc.)
has 'dynamic_simple_features' => (
    is      => 'rw',
    isa     => 'HashRef[Int]',
    default => sub { {} },
);

# # simple features that get more than 1 argument as input
# has 'multiarg_simple_features' => (
#     is => 'rw',
#     isa => 'HashRef[Int]',
#     default => sub { {} },
# );

# CACHING

has 'use_edge_features_cache' => (
    is      => 'ro',
    isa     => 'Bool',
    default => '0',
);

# using cache turned off to fit into RAM by default
# turn on if training with a lot of RAM or on small training data
# turned off when parsing (does not make any sense for parsing)

has 'edge_features_cache' => (
    is      => 'rw',
    isa     => 'HashRef[ArrayRef[Str]]',
    default => sub { {} },
);

has pmi_model => (
    is      => 'rw',
    isa     => 'Maybe[Treex::Tool::Parser::MSTperl::ModelAdditional]',
    default => undef,
);

has cprob_model => (
    is      => 'rw',
    isa     => 'Maybe[Treex::Tool::Parser::MSTperl::ModelAdditional]',
    default => undef,
);

sub BUILD {
    my ($self) = @_;

    # ignore some settings if in parsing-only mode
    #     if ( !$self->training ) {
    #         $self->use_edge_features_cache(0);
    #     }

    # features
    foreach my $feature ( @{ $self->feature_codes_from_config } ) {
        $self->set_feature($feature);
    }

    $self->feature_count( scalar( @{ $self->feature_codes } ) );
    $self->simple_feature_count( scalar( @{ $self->simple_feature_codes } ) );

    return;
}

sub set_feature {
    my ( $self, $feature_code ) = @_;

    if ( $self->feature_codes_hash->{$feature_code} ) {
        warn "Feature '$feature_code' is defined more than once; " .
            "disregarding its later definitions.\n";
    } else {

        # get simple features
        my $isArrayFeature   = 0;
        my $isDynamicFeature = 0;
        my @simple_features_indexes;
        my %simple_features_hash;
        foreach my $simple_feature_code ( split( /\|/, $feature_code ) ) {

            # checks
            if ( $simple_features_hash{$simple_feature_code} ) {
                warn "Simple feature '$simple_feature_code' " .
                    "is used more than once in '$feature_code'; " .
                    "disregarding its later uses.\n";
                next;
            }
            if ( !$self->simple_feature_codes_hash->{$simple_feature_code} ) {

                # this simple feature has not been used at all yet
                $self->set_simple_feature($simple_feature_code);
            }

            # save
            my $simple_feature_index =
                $self->simple_feature_indexes->{$simple_feature_code};
            $simple_features_hash{$simple_feature_code} = 1;
            if ( $self->array_simple_features->{$simple_feature_index} ) {
                $isArrayFeature = 1;
            }
            if ( $self->dynamic_simple_features->{$simple_feature_index} ) {
                $isDynamicFeature = 1;
            }
            push @simple_features_indexes, $simple_feature_index;
        }

        # save
        my $feature_index = scalar( @{ $self->feature_codes } );
        $self->feature_codes_hash->{$feature_code} = 1;
        $self->feature_indexes->{$feature_code}    = $feature_index;
        push @{ $self->feature_codes }, $feature_code;
        push @{ $self->feature_simple_features_indexes },
            [@simple_features_indexes];
        if ($isArrayFeature) {
            $self->array_features->{$feature_index} = 1;
        }
        if ($isDynamicFeature) {
            $self->dynamic_features->{$feature_index} = 1;
        }
    }

    return;
}

sub set_simple_feature {
    my ( $self, $simple_feature_code ) = @_;

    # get sub reference and field index
    my $simple_feature_index = scalar @{ $self->simple_feature_codes };
    my $simple_feature_sub;
    my $simple_feature_field;

    # simple parent/child feature
    if ( $simple_feature_code =~ /^([a-zA-Z0-9_]+)$/ ) {

        if ( $simple_feature_code =~ /^([a-z0-9_]+)$/ ) {

            # child feature
            $simple_feature_sub   = \&{feature_child};
            $simple_feature_field = $1;
        } elsif ( $simple_feature_code =~ /^([A-Z0-9_]+)$/ ) {

            # parent feature
            $simple_feature_sub   = \&{feature_parent};
            $simple_feature_field = lc($1);
        } else {
            die "Incorrect simple feature format '$simple_feature_code'. " .
                "Use lowercase (" . lc($simple_feature_code) .
                ") for child node and UPPERCASE (" . uc($simple_feature_code) .
                ") for parent node.\n";
        }

        # first/second/(left sibling)/(right sibling)/Grandparent/grandchildren
        # node feature
    } elsif ( $simple_feature_code =~ /^([12gGlr])\.([a-z0-9_]+)$/ ) {

        $simple_feature_field = $2;

        if ( $1 eq '1' ) {

            # first node feature
            $simple_feature_sub = \&{feature_first};
        } elsif ( $1 eq '2' ) {

            # second node feature
            $simple_feature_sub = \&{feature_second};
        } elsif ( $1 eq 'g' ) {

            # grandchildren node feature
            $simple_feature_sub = \&{feature_grandchildren};
        } elsif ( $1 eq 'G' ) {

            # grandparent node feature
            $simple_feature_sub = \&{feature_grandparent};
        } elsif ( $1 eq 'l' ) {

            # left sibling edge child feature
            $simple_feature_sub = \&{feature_left_sibling};
        } elsif ( $1 eq 'r' ) {

            # right sibling edge child feature
            $simple_feature_sub = \&{feature_right_sibling};
        } else {
            croak "Assertion failed!";
        }

        # function feature
    } elsif (
        $simple_feature_code
        =~ /^([12gGlr\.a-z]+|[A-Z]+)\([-a-z0-9_,]*\)$/
        )
    {
        my $function_name = $1;
        $simple_feature_sub =
            $self->get_simple_feature_sub_reference($function_name);

        if ($function_name eq 'between'
            || $function_name eq 'foreach'
            || substr( $function_name, 0, 2 ) eq 'g.'
            )
        {

            # array function
            $self->array_simple_features->{$simple_feature_index} = 1;
        }

        if ($function_name eq 'LABEL'
            || $function_name eq 'l.label' || $function_name eq 'prevlabel'
            || $function_name eq 'G.label'
            || $function_name eq 'g.label'
            )
        {

            # dynamic feature
            $self->dynamic_simple_features->{$simple_feature_index} = 1;
        }

        # set $simple_feature_field
        if ( $simple_feature_code =~ /$function_name\(\)$/ ) {

            # no-arg function feature
            $simple_feature_field = [];
        } elsif ( $simple_feature_code =~ /$function_name\(([-a-z0-9_]+)\)$/ ) {

            # one-arg function feature
            $simple_feature_field = $1;
        } elsif (
            $simple_feature_code
            =~ /$function_name\(([-a-z0-9_,]+)\)$/
            )
        {

            # multiarg function feature
            my @fields = split /,/, $1;
            $simple_feature_field = \@fields;
        } else {
            die "Incorrect simple function feature format " .
                "'$simple_feature_code'.\n";
        }
    } else {
        die "Incorrect simple feature format '$simple_feature_code'.\n";
    }

    # if $simple_feature_field is (a ref to) an array of field names,
    #   handles that correctly by iterating over the array and returning
    #   an array of field indexes;
    # if there is an integer argument instead of a field name,
    #   detects that and keeps that integer unchanged
    my $simple_feature_sub_arguments =
        $self->config->field_name2index($simple_feature_field);

    # save
    $self->simple_feature_codes_hash->{$simple_feature_code} = 1;
    $self->simple_feature_indexes->{$simple_feature_code} =
        $simple_feature_index;
    push @{ $self->simple_feature_codes }, $simple_feature_code;
    push @{ $self->simple_feature_subs },  $simple_feature_sub;
    push @{ $self->simple_feature_sub_arguments },
        $simple_feature_sub_arguments;

    return;
}

# FEATURES COMPUTATION

# array (ref) of all features of the edge,
# in the form of "feature_index:values_string" strings,
# where feature_index is the index of the feature
# (index in feature_codes, translatable via feature_indexes)
# and values_string are values of corresponding simple features,
# joined together by '|'
# (if any of the simple features does not return a value, the whole feature
# is not present)
# TODO maybe not returning a value is still a valuable information -> include?
sub get_all_features {

    # Edge; 0: all features, 1: only dynamic, -1: only non-dynamic
    # either get only dynamic features or get all but dynamic features
    my ( $self, $edge, $only_dynamic_features ) = @_;

    # try to get features from cache
    # TODO: cache not used now and probably does not even work:
    # check&fix or remove
    my $edge_signature;
    if ( $self->use_edge_features_cache ) {
        $edge_signature = $edge->signature();

        my $cache_features = $self->edge_features_cache->{$edge_signature};
        if ($cache_features) {
            return $cache_features;
        }
    }

    # double else: if cache not used or if edge features not found in cache
    my $simple_feature_values = $self->get_simple_feature_values_array($edge);
    my @features;
    my $features_count = $self->feature_count;
    for (
        my $feature_index = 0;
        $feature_index < $features_count;
        $feature_index++
        )
    {
        if ($only_dynamic_features
            && $only_dynamic_features == 1
            && !$self->dynamic_features->{$feature_index}
            )
        {
            next;
        } elsif (
            $only_dynamic_features
            && $only_dynamic_features == -1
            && $self->dynamic_features->{$feature_index}
            )
        {
            next;
        } else {
            my $feature_value =
                $self->get_feature_value( $feature_index, $simple_feature_values );
            if ( $self->array_features->{$feature_index} ) {

                #it is an array feature, the returned value is an array reference
                foreach my $value ( @{$feature_value} ) {
                    push @features, "$feature_index:$value";
                }
            } else {

                #it is not an array feature, the returned value is a string
                if ( $feature_value ne '' ) {
                    push @features, "$feature_index:$feature_value";
                }
            }
        }
    }

    # save result in cache
    if ( $self->use_edge_features_cache ) {
        $self->edge_features_cache->{$edge_signature} = \@features;
    }

    return \@features;
}

# returns value of feature: simple feature values joined by '|'
# or '' if any of them is undefined or empty;
# for an array feature returns an array (ref) of these
# or an empty array (ref)
sub get_feature_value {
    my ( $self, $feature_index, $simple_feature_values ) = @_;

    my $simple_features_indexes =
        $self->feature_simple_features_indexes->[$feature_index];

    if ( $self->array_features->{$feature_index} ) {
        my $feature_value =
            $self->get_array_feature_value(
            $simple_features_indexes,
            $simple_feature_values, 0
            );
        if ($feature_value) {
            return $feature_value;
        } else {
            return [];
        }
    } else {
        my @values;
        foreach my $simple_feature_index ( @{$simple_features_indexes} ) {
            my $value = $simple_feature_values->[$simple_feature_index];
            if ( defined $value && $value ne '' ) {
                push @values, $value;
            } else {
                return '';
            }
        }

        my $feature_value = join '|', @values;
        return $feature_value;
    }
}

# for features containing subfeatures that return an array of values
sub get_array_feature_value {
    my (
        $self,
        $simple_features_indexes,
        $simple_feature_values,
        $start_from
    ) = @_;

    # get value at this position (position = $start_from)
    my $simple_feature_index = $simple_features_indexes->[$start_from];
    my $value                = $simple_feature_values->[$simple_feature_index];
    if ( !$self->array_simple_features->{$simple_feature_index} ) {

        # if not an array reference
        $value = [ ($value) ];    # make it an array reference
    }

    my $simple_features_count = scalar @{$simple_features_indexes};
    if ( $start_from < $simple_features_count - 1 ) {

        # not the last simple feature => have to recurse
        my $append =
            $self->get_array_feature_value(
            $simple_features_indexes,
            $simple_feature_values, $start_from + 1
            );
        my @values;
        foreach my $my_value ( @{$value} ) {
            foreach my $append_value ( @{$append} ) {
                my $add_value = "$my_value|$append_value";
                push @values, $add_value;
            }
        }
        return [@values];
    } else {    # else bottom of recursion
        return $value;
    }
}

# SIMPLE FEATURES

sub get_simple_feature_values_array {
    my ( $self, $edge ) = @_;

    my @simple_feature_values;
    my $simple_feature_count = $self->simple_feature_count;
    for (
        my $simple_feature_index = 0;
        $simple_feature_index < $simple_feature_count;
        $simple_feature_index++
        )
    {
        my $sub = $self->simple_feature_subs->[$simple_feature_index];

        # If the simple feature has one parameter,
        # then $arguments is the one argument;
        # if the simple feature has more than one parameter,
        # then $arguments is a reference to an array of arguments.
        my $arguments =
            $self->simple_feature_sub_arguments->[$simple_feature_index];
        my $value = &$sub( $self, $edge, $arguments );
        push @simple_feature_values, $value;
    }

    return [@simple_feature_values];
}

my %simple_feature_sub_references = (
    'LABEL'             => \&{feature_parent_label},
    'prevlabel'         => \&{feature_previous_label},
    'l.label'           => \&{feature_previous_label},
    'G.label'           => \&{feature_grandparent_label},
    'g.label'           => \&{feature_grandchildren_label},
    'distance'          => \&{feature_distance},
    'G.distance'        => \&{feature_grandparent_distance},
    'attdir'            => \&{feature_attachement_direction},
    'G.attdir'          => \&{feature_grandparent_attachement_direction},    # grandparent to child
    'preceding'         => \&{feature_preceding_child},
    'PRECEDING'         => \&{feature_preceding_parent},
    '1.preceding'       => \&{feature_preceding_first},
    '2.preceding'       => \&{feature_preceding_second},
    'following'         => \&{feature_following_child},
    'FOLLOWING'         => \&{feature_following_parent},
    '1.following'       => \&{feature_following_first},
    '2.following'       => \&{feature_following_second},
    'between'           => \&{feature_between},
    'foreach'           => \&{feature_foreach},
    'equals'            => \&{feature_equals},
    'equalspc'          => \&{feature_equals_pc},
    'equalspcat'        => \&{feature_equals_pc_at},
    'arrayat'           => \&{feature_array_at_child},
    'ARRAYAT'           => \&{feature_array_at_parent},
    'arrayatcp'         => \&{feature_array_at_cp},
    'isfirst'           => \&{feature_child_is_first_in_sentence},
    'ISFIRST'           => \&{feature_parent_is_first_in_sentence},
    'islast'            => \&{feature_child_is_last_in_sentence},
    'ISLAST'            => \&{feature_parent_is_last_in_sentence},
    'isfirstchild'      => \&{feature_child_is_first_child},
    'islastchild'       => \&{feature_child_is_last_child},
    'islastleftchild'   => \&{feature_child_is_last_left_child},
    'isfirstrightchild' => \&{feature_child_is_first_right_child},
    'childno'           => \&{feature_number_of_childs_children},
    'CHILDNO'           => \&{feature_number_of_parents_children},
    'substr'            => \&{feature_substr_child},
    'SUBSTR'            => \&{feature_substr_parent},
    'pmi'               => \&{feature_pmi},
    'pmibucketed'       => \&{feature_pmi_bucketed},
    'pmirounded'        => \&{feature_pmi_rounded},
    'pmid'              => \&{feature_pmi_d},
    'cprob'             => \&{feature_cprob},
    'cprobbucketed'     => \&{feature_cprob_bucketed},
    'cprobrounded'      => \&{feature_cprob_rounded},

    # obsolete
    #    'pmitworounded'     => \&{feature_pmi_2_rounded},
    #    'pmithreerounded'   => \&{feature_pmi_3_rounded},
    #    'cprobtworounded'   => \&{feature_cprob_2_rounded},
    #    'cprobthreerounded' => \&{feature_cprob_3_rounded},
);

sub get_simple_feature_sub_reference {
    my ( $self, $simple_feature_function ) = @_;

    if ( $simple_feature_sub_references{$simple_feature_function} ) {
        return $simple_feature_sub_references{$simple_feature_function};
    } else {
        croak "Unknown feature function '$simple_feature_function'!";
    }
}

# returns undef if there is no grandparent, i.e. the parent is the root
sub get_grandparent {
    my ( $self, $edge ) = @_;

    return ( $edge->parent )->parent;
}

sub feature_distance {
    my ( $self, $edge ) = @_;

    return $self->feature_distance_generic( $edge->parent, $edge->child );
}

sub feature_grandparent_distance {
    my ( $self, $edge ) = @_;

    my $grandparent = $self->get_grandparent($edge);
    if ( defined $grandparent ) {
        return $self->feature_distance_generic( $edge->parent, $edge->child );
    } else {
        return '#novalue#';
    }
}

sub feature_distance_generic {
    my ( $self, $node1, $node2 ) = @_;

    my $distance = $node1->ord - $node2->ord;

    my $bucket = $self->config->distance2bucket->{$distance};
    if ( defined $bucket ) {
        return $bucket;
    } else {
        if ( $distance <= $self->config->minBucket ) {
            return $self->config->minBucket;
        } else {    # $distance >= $self->maxBucket
            return $self->config->maxBucket;
        }
    }
}

sub feature_attachement_direction {
    my ( $self, $edge ) = @_;

    return $self->feature_attachement_direction_generic(
        $edge->parent, $edge->child
    );
}

sub feature_grandparent_attachement_direction {
    my ( $self, $edge ) = @_;

    my $grandparent = $self->get_grandparent($edge);
    if ( defined $grandparent ) {
        return $self->feature_attachement_direction_generic(
            $edge->parent, $edge->child
        );
    } else {
        return '#novalue#';
    }
}

sub feature_attachement_direction_generic {
    my ( $self, $node1, $node2 ) = @_;

    if ( $node1->ord < $node2->ord ) {
        return -1;
    } else {
        return 1;
    }
}

sub feature_child {
    my ( $self, $edge, $field_index ) = @_;
    return ( $edge->child->fields->[$field_index] );
}

sub feature_parent {
    my ( $self, $edge, $field_index ) = @_;
    return ( $edge->parent->fields->[$field_index] );
}

sub feature_grandparent {
    my ( $self, $edge, $field_index ) = @_;

    my $grandparent = $self->get_grandparent($edge);
    if ( defined $grandparent ) {
        return ( $grandparent->fields->[$field_index] );
    } else {
        return '#novalue#';
    }
}

sub feature_parent_label {
    my ( $self, $edge ) = @_;
    return ( $edge->parent->label );
}

sub feature_previous_label {
    my ( $self, $edge ) = @_;

    my $left_sibling = $self->get_left_sibling($edge);
    if ( defined $left_sibling ) {
        return ( $left_sibling->child->label );
    } else {
        return $self->config->SEQUENCE_BOUNDARY_LABEL;
    }
}

sub feature_grandparent_label {
    my ( $self, $edge ) = @_;

    my $grandparent = $self->get_grandparent($edge);
    if ( defined $grandparent ) {
        return ( $grandparent->label );
    } else {
        return '#novalue#';
    }
}

sub feature_first {
    my ( $self, $edge, $field_index ) = @_;
    return ( $edge->first->fields->[$field_index] );
}

sub feature_second {
    my ( $self, $edge, $field_index ) = @_;
    return ( $edge->second->fields->[$field_index] );
}

sub feature_left_sibling {
    my ( $self, $edge, $field_index ) = @_;

    my $left_sibling = $self->get_left_sibling($edge);
    if ( defined $left_sibling ) {
        return ( $left_sibling->child->fields->[$field_index] );
    } else {
        return '#start#';
    }
}

sub feature_right_sibling {
    my ( $self, $edge, $field_index ) = @_;

    my $right_sibling = $self->get_right_sibling($edge);
    if ( defined $right_sibling ) {
        return ( $right_sibling->child->fields->[$field_index] );
    } else {
        return '#end#';
    }
}

sub get_left_sibling {
    my ( $self, $edge ) = @_;

    my $siblings = $edge->parent->children;
    my $is_first = ( $siblings->[0]->child->ord == $edge->child->ord );
    if ($is_first) {

        # there is no left sibling to the leftmost node
        return;
    } else {

        # find my position among parent's children (is at least 1)
        my $my_index = 1;
        while ( $siblings->[$my_index]->child->ord != $edge->child->ord ) {
            $my_index++;
        }

        # now ($my_index-1) is the index of my (closest) left sibling
        return ( $siblings->[ $my_index - 1 ] );
    }
}

sub get_right_sibling {
    my ( $self, $edge ) = @_;

    my $siblings           = $edge->parent->children;
    my $last_sibling_index = scalar(@$siblings) - 1;
    my $is_last            = (
        $siblings->[$last_sibling_index]->child->ord
            == $edge->child->ord
    );
    if ($is_last) {

        # there is no right sibling to the rightmost node
        return;
    } else {

        # find my position among parent's children
        # (is at most $last_sibling_index - 1)
        my $my_index = $last_sibling_index - 1;
        while ( $siblings->[$my_index]->child->ord != $edge->child->ord ) {
            $my_index--;
        }

        # now ($my_index+1) is the index of my (closest) right sibling
        return $siblings->[ $my_index + 1 ];
    }
}

sub feature_preceding_child {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->child->ord - 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->parent->ord == $node->ord ) {

            # no gap between nodes
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#start#';
    }
}

sub feature_preceding_parent {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->parent->ord - 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->child->ord == $node->ord ) {

            # no gap between nodes
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#start#';
    }
}

sub feature_following_child {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->child->ord + 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->parent->ord == $node->ord ) {

            # no gap between nodes
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#end#';
    }
}

sub feature_following_parent {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->parent->ord + 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->child->ord == $node->ord ) {

            # no gap between nodes
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#end#';
    }
}

sub feature_preceding_first {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->first->ord - 1 );

    # $node may be undef
    if ($node) {
        return $node->fields->[$field_index];
    } else {
        return '#start#';
    }
}

sub feature_preceding_second {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->second->ord - 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->first->ord == $node->ord ) {

            # node preceding second node is first node
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#start#';
    }
}

sub feature_following_first {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->first->ord + 1 );

    # $node may be undef
    if ($node) {
        if ( $edge->second->ord == $node->ord ) {

            # node following first node is second node
            return '#mid#';
        } else {
            return $node->fields->[$field_index];
        }
    } else {
        return '#end#';
    }
}

sub feature_following_second {
    my ( $self, $edge, $field_index ) = @_;

    my $node = $edge->sentence->getNodeByOrd( $edge->second->ord + 1 );

    # $node may be undef
    if ($node) {
        return $node->fields->[$field_index];
    } else {
        return '#end#';
    }
}

sub feature_between {
    my ( $self, $edge, $field_index ) = @_;

    my @values;
    my $from;
    my $to;
    if ( $edge->parent->ord < $edge->child->ord ) {
        $from = $edge->parent->ord + 1;
        $to   = $edge->child->ord - 1;
    } else {
        $from = $edge->child->ord + 1;
        $to   = $edge->parent->ord - 1;
    }

    # TODO: use precomputed values instead

    for ( my $ord = $from; $ord <= $to; $ord++ ) {
        push @values,
            $edge->sentence->getNodeByOrd($ord)->fields->[$field_index];
    }
    return [@values];

    #     my $len = $to - $from;
    #     if ($len >= 0) {
    #         return $edge->sentence->betweenFeatureValues->
    #            {$field_index}->[$from]->[$len];
    #     } else {
    #         return;
    #     }

}

sub feature_foreach {
    my ( $self, $edge, $field_index ) = @_;

    my $values = $edge->child->fields->[$field_index];
    if ($values) {
        my @values = split / /, $edge->child->fields->[$field_index];
        return [@values];
    } else {
        return '';
    }
}

sub feature_equals {
    my ( $self, $edge, $field_indexes ) = @_;

    # equals takes two arguments
    if ( @{$field_indexes} == 2 ) {
        my ( $field_index_1, $field_index_2 ) = @{$field_indexes};
        my $values_1 = $edge->child->fields->[$field_index_1];
        my $values_2 = $edge->child->fields->[$field_index_2];

        # we handle undefines and empties specially
        if (
            defined $values_1
            && $values_1 ne ''
            && defined $values_2
            && $values_2 ne ''
            )
        {
            my $result   = 0;                      # default not equal
            my @values_1 = split / /, $values_1;
            my @values_2 = split / /, $values_2;

            # try to find a match
            foreach my $value_1 (@values_1) {
                foreach my $value_2 (@values_2) {
                    if ( $value_1 eq $value_2 ) {
                        $result = 1;               # one match is enough
                    }
                }
            }
            return $result;
        } else {
            return -1;                             # undef
        }
    } else {
        croak "equals() takes TWO arguments!!!";
    }
}

# only difference to equals is the line:
# my $values_1 = $edge->PARENT->fields->[$field_index_1];
sub feature_equals_pc {
    my ( $self, $edge, $field_indexes ) = @_;

    # equals takes two arguments
    if ( @{$field_indexes} == 2 ) {
        my ( $field_index_1, $field_index_2 ) = @{$field_indexes};
        my $values_1 = $edge->parent->fields->[$field_index_1];
        my $values_2 = $edge->child->fields->[$field_index_2];

        # we handle undefines and empties specially
        if (
            defined $values_1
            && $values_1 ne ''
            && defined $values_2
            && $values_2 ne ''
            )
        {
            my $result   = 0;                      # default not equal
            my @values_1 = split / /, $values_1;
            my @values_2 = split / /, $values_2;

            # try to find a match
            foreach my $value_1 (@values_1) {
                foreach my $value_2 (@values_2) {
                    if ( $value_1 eq $value_2 ) {
                        $result = 1;               # one match is enough
                    }
                }
            }
            return $result;
        } else {
            return -1;                             # undef
        }
    } else {
        croak "equals() takes TWO arguments!!!";
    }
}

# sub equalsat - does not make sense

# whether the character at the given position of the given field
#  equals in parent and in child
sub feature_equals_pc_at {
    my ( $self, $edge, $arguments ) = @_;

    # equals takes two arguments
    if ( @{$arguments} == 2 ) {
        my ( $field_index, $position ) = @{$arguments};
        my $field_parent = $edge->parent->fields->[$field_index];
        my $field_child  = $edge->child->fields->[$field_index];

        # we handle undefines and too short fields specially
        if (
            defined $field_parent
            && length $field_parent > $position
            && defined $field_child
            && length $field_child > $position
            )
        {
            my $value_parent = substr $field_parent, $position, 1;
            my $value_child  = substr $field_child,  $position, 1;
            if ( $value_parent eq $value_child ) {
                return 1;
            } else {
                return 0;
            }
        } else {
            return -1;    # undef
        }
    } else {
        croak "equals() takes TWO arguments!!!";
    }
}

# substring (field, start, length)
sub feature_substr_child {
    my ( $self, $edge, $arguments ) = @_;

    # substr takes two or three arguments
    if ( @{$arguments} != 3 && @{$arguments} != 2 ) {
        croak "substr() takes THREE or TWO arguments!!!";
    } else {
        my ( $field_index, $start, $length ) = @{$arguments};
        my $field = $edge->child->fields->[$field_index];

        my $value = '';
        if ( defined $field ) {
            if ( defined $length ) {
                $value = substr( $field, $start, $length );
            } else {
                $value = substr( $field, $start );
            }
        }

        return $value;
    }
}

# substring (field, start, length)
sub feature_substr_parent {
    my ( $self, $edge, $arguments ) = @_;

    # substr takes two or three arguments
    if ( @{$arguments} != 3 && @{$arguments} != 2 ) {
        croak "substr() takes THREE or TWO arguments!!!";
    } else {
        my ( $field_index, $start, $length ) = @{$arguments};
        my $field = $edge->parent->fields->[$field_index];

        my $value = '';
        if ( defined $field ) {
            if ( defined $length ) {
                $value = substr( $field, $start, $length );
            } else {
                $value = substr( $field, $start );
            }
        }

        return $value;
    }
}

# arrayat (array, index)
sub feature_array_at_child {
    my ( $self, $edge, $arguments ) = @_;

    # arrayat takes two arguments
    if ( @{$arguments} != 2 ) {
        croak "arrayat() takes TWO arguments!!!";
    } else {
        my ( $array_field, $index_field ) = @{$arguments};
        my $array = $edge->child->fields->[$array_field];
        my $index = $edge->child->fields->[$index_field];

        my @array = split / /, $array;
        my $value = $array[$index];
        if ( !defined $value ) {
            $value = '';
        }

        return $value;
    }
}

sub feature_array_at_parent {
    my ( $self, $edge, $arguments ) = @_;

    # arrayat takes two arguments
    if ( @{$arguments} != 2 ) {
        croak "arrayat() takes TWO arguments!!!";
    } else {
        my ( $array_field, $index_field ) = @{$arguments};
        my $array = $edge->parent->fields->[$array_field];
        my $index = $edge->parent->fields->[$index_field];

        my @array = split / /, $array;
        my $value = $array[$index];
        if ( !defined $value ) {
            $value = '';
        }

        return $value;
    }
}

# arrayatcp (array, index)
sub feature_array_at_cp {
    my ( $self, $edge, $arguments ) = @_;

    # arrayat takes two arguments
    if ( @{$arguments} != 2 ) {
        croak "arrayat() takes TWO arguments!!!";
    } else {
        my ( $array_field, $index_field ) = @{$arguments};
        my $array = $edge->child->fields->[$array_field];
        my $index = $edge->parent->fields->[$index_field];

        my @array = split / /, $array;
        my $value = $array[$index];
        if ( !defined $value ) {
            $value = '';
        }

        return $value;
    }
}

sub feature_child_is_first_in_sentence {
    my ( $self, $edge ) = @_;

    if ( $edge->child->ord == 1 ) {
        return 1;
    } else {
        return 0;
    }
}

sub feature_parent_is_first_in_sentence {
    my ( $self, $edge ) = @_;

    if ( $edge->parent->ord == 1 ) {
        return 1;
    } else {
        return 0;
    }
}

sub feature_child_is_last_in_sentence {
    my ( $self, $edge ) = @_;

    # last ord = number of nodes (because ords are 1-based, 0 is the root node)
    if ( $edge->child->ord == scalar( @{ $edge->sentence->nodes } ) ) {
        return 1;
    } else {
        return 0;
    }
}

sub feature_parent_is_last_in_sentence {
    my ( $self, $edge ) = @_;

    # last ord = number of nodes (because ords are 1-based, 0 is the root node)
    if ( $edge->parent->ord == scalar( @{ $edge->sentence->nodes } ) ) {
        return 1;
    } else {
        return 0;
    }
}

sub feature_child_is_first_child {
    my ( $self, $edge ) = @_;

    my $children = $edge->parent->children;
    if ( $children->[0]->child->ord == $edge->child->ord ) {
        return 1;
    } else {
        return 0;
    }
}

sub feature_child_is_last_child {
    my ( $self, $edge ) = @_;

    my $children    = $edge->parent->children;
    my $childrenNum = scalar(@$children);
    if ( $children->[ $childrenNum - 1 ]->child->ord == $edge->child->ord ) {
        return 1;
    } else {
        return 0;
    }
}

sub feature_child_is_first_right_child {
    my ( $self, $edge ) = @_;

    my $is_right = ( $edge->parent->ord < $edge->child->ord );
    if ($is_right) {
        my $siblings = $edge->parent->children;
        my $is_first = ( $siblings->[0]->child->ord == $edge->child->ord );
        if ($is_first) {

            # is right & is first (= leftmost) of all siblings
            return 1;
        } else {

            # find my position among parent's children (is at least 1)
            my $my_index = 1;
            while ( $siblings->[$my_index]->child->ord != $edge->child->ord ) {
                $my_index++;
            }

            # now ($my_index-1) is the index of my (closest) left sibling
            my $sibling_is_left =
                (
                $siblings->[ $my_index - 1 ]->child->ord
                    < $edge->parent->ord
                );
            if ($sibling_is_left) {

                # is right and closest left sibling is left
                return 1;
            } else {

                # is right but not the first one
                return 0;
            }
        }
    } else {

        # is left
        return 0;
    }
}

sub feature_child_is_last_left_child {
    my ( $self, $edge ) = @_;

    my $is_left = ( $edge->child->ord < $edge->parent->ord );
    if ($is_left) {
        my $siblings           = $edge->parent->children;
        my $last_sibling_index = scalar(@$siblings) - 1;
        my $is_last            = (
            $siblings->[$last_sibling_index]->child->ord
                == $edge->child->ord
        );
        if ($is_last) {

            # is left & is last of all siblings
            return 1;
        } else {

            # find my position among parent's children
            # (is at most $last_sibling_index - 1)
            my $my_index = $last_sibling_index - 1;
            while ( $siblings->[$my_index]->child->ord != $edge->child->ord ) {
                $my_index--;
            }

            # now ($my_index+1) is the index of my (closest) right sibling
            my $sibling_is_right =
                (
                $edge->parent->ord
                    < $siblings->[ $my_index + 1 ]->child->ord
                );
            if ($sibling_is_right) {

                # is left and closest right sibling is right
                return 1;
            } else {

                # is left but not the last one
                return 0;
            }
        }
    } else {

        # is right
        return 0;
    }
}

sub feature_number_of_childs_children {
    my ( $self, $edge ) = @_;

    my $children = $edge->child->children;
    if ( $children && scalar(@$children) ) {
        return scalar(@$children);
    } else {
        return 0;
    }
}

sub feature_number_of_parents_children {
    my ( $self, $edge ) = @_;

    my $children = $edge->parent->children;
    if ( $children && scalar(@$children) ) {
        return scalar(@$children);
    } else {
        return 0;
    }
}

sub feature_additional_model {
    my ( $self, $edge, $field_index, $model ) = @_;

    my $child  = $edge->child->fields->[$field_index];
    my $parent = $edge->parent->fields->[$field_index];

    if ( defined $child && defined $parent ) {
        return $model->get_value( $child, $parent );
    } else {
        croak "Either child or parent is undefined in additional model feature, " .
            "this should not happen!";
    }
}

sub feature_additional_model_bucketed {
    my ( $self, $edge, $field_index, $model ) = @_;

    my $child  = $edge->child->fields->[$field_index];
    my $parent = $edge->parent->fields->[$field_index];

    if ( defined $child && defined $parent ) {
        return $model->get_bucketed_value( $child, $parent );
    } else {
        croak "Either child or parent is undefined in additional model feature, " .
            "this should not happen!";
    }
}

sub feature_additional_model_rounded {
    my ( $self, $edge, $parameters, $model ) = @_;

    my ( $field_index, $rounding ) = @$parameters;
    my $child  = $edge->child->fields->[$field_index];
    my $parent = $edge->parent->fields->[$field_index];

    if ( defined $child && defined $parent ) {
        return $model->get_rounded_value( $child, $parent, $rounding );
    } else {
        croak "Either child or parent is undefined in additional model feature, " .
            "this should not happen!";
    }
}

sub feature_additional_model_d {
    my ( $self, $edge, $parameters, $model ) = @_;

    my ( $field_index_c, $field_index_p ) = @$parameters;
    my $child  = $edge->child->fields->[$field_index_c];
    my $parent = $edge->parent->fields->[$field_index_p];

    if ( defined $child && defined $parent ) {
        return $model->get_rounded_value( $child, $parent );
    } else {
        croak "Either child or parent is undefined in additional model feature, " .
            "this should not happen!";
    }
}

sub feature_pmi {
    my ( $self, $edge, $field_index ) = @_;

    return $self->feature_additional_model( $edge, $field_index, $self->pmi_model );
}

sub feature_pmi_bucketed {
    my ( $self, $edge, $field_index ) = @_;

    return $self->feature_additional_model_bucketed( $edge, $field_index, $self->pmi_model );
}

sub feature_pmi_rounded {
    my ( $self, $edge, $parameters ) = @_;

    return $self->feature_additional_model_rounded( $edge, $parameters, $self->pmi_model );
}

sub feature_pmi_d {
    my ( $self, $edge, $parameters ) = @_;

    return $self->feature_additional_model_d( $edge, $parameters, $self->pmi_model );
}

sub feature_pmi_2_rounded {
    my ( $self, $edge, $field_index ) = @_;

    my @params = ( $field_index, 1 );
    return $self->feature_pmi_rounded( $edge, \@params );
}

sub feature_pmi_3_rounded {
    my ( $self, $edge, $field_index ) = @_;

    my @params = ( $field_index, 2 );
    return $self->feature_pmi_rounded( $edge, \@params );
}

sub feature_cprob {
    my ( $self, $edge, $field_index ) = @_;

    return $self->feature_additional_model( $edge, $field_index, $self->cprob_model );
}

sub feature_cprob_bucketed {
    my ( $self, $edge, $field_index ) = @_;

    return $self->feature_additional_model_bucketed( $edge, $field_index, $self->cprob_model );
}

sub feature_cprob_rounded {
    my ( $self, $edge, $parameters ) = @_;

    return $self->feature_additional_model_rounded( $edge, $parameters, $self->cprob_model );
}

sub feature_cprob_2_rounded {
    my ( $self, $edge, $field_index ) = @_;

    my @params = ( $field_index, 1 );
    return $self->feature_cprob_rounded( $edge, \@params );
}

sub feature_cprob_3_rounded {
    my ( $self, $edge, $field_index ) = @_;

    my @params = ( $field_index, 2 );
    return $self->feature_cprob_rounded( $edge, \@params );
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::FeaturesControl

=head1 DESCRIPTION

Controls the features used in the model.

=head2 Features

TODO: outdated, superceded by use of config file -> rewrite

Each feature has a form C<code:value>. The code desribes the information which
is relevant for the feature, and the value is the information retained from
the dependency edge (and possibly other parts of the sentence
(L<Treex::Tool::Parser::MSTperl::Sentence>) stored in C<sentence> field).

For example, the feature C<L|l:být|pes> means that the lemma of the parent node
(the governing word) is "být" and the lemma of its child node (the dependent
node) is "pes".

Each (proper) feature is composed of several simple features. In the
aforementioned example, the simple feature codes were C<L> and C<l> and their
values "být" and "pes", respectively. Each simple feature code is a string
(case sensitive) and its value is also a string. The simple feature codes are
joined together by the C<|> sign to form the code of the proper feature, and
similarly, the simple feature values joined by C<|> form the proper feature
value. Then, the proper feature code and value are joined together by C<:>.
(Therefore, the codes and values of the simple features must not contain the
C<|> and the C<:> signs.)

By a naming convention,
if the same simple feature can be computed for both the parent node and its
child node, their codes are the same but for the case, which is upper for the
parent and lower for the child. If this is not applicable, an uppercase
code is used.

For higher effectiveness the simple feature codes are translated to integers
(see C<simple_feature_codes>).

In reality the feature codes are translated to integers as well (see
C<feature_codes>), but this is only an internal issue. You can see these
numbers in the model file if you use the default L<Data::Dumper> format (see
C<load> and C<store>). However, if you use the tsv format (see C<load_tsv>,
C<store_tsv>), you will see the real string feature codes.

Currently the following simple features are available. Any subset of them can
be used to form a proper feature, but their order should follow their order of
appearance in this list (still, this is only a cleanliness and readability
thing, it does not affect the function of the parser in any way).

=over 4

=item Distance (D)

Distance of the two nodes in the sentence, computed as order of the parent
minus the order of the child. Eg. for the sentence "To je prima pes ." and the
feature D computed on nodes "je" and "pes" (parent and child respectively),
the order of "je" is 2 and the order of "pes" is 4, yielding the feature value
of 2 - 4 = -2. This leads to a feature C<D:-2>.

=item Form (F, f)

The form of the node, i.e. the word exactly as it appears in the sentence text.

Currently not used as it has not lead to any improvement in the parsing.

=item Lemma (L, l)

The morphological lemma of the node.

=item preceding tag (S, s)

The morphological tag (or POS tag if you like) of the node preceding (ord-wise)
the node.

=item Tag (T, t)

The morphological tag of the node.

=item following tag (U, u)

The morphological tag of the node following (ord-wise) the node.

=item between tag (B)

The morphological tag of each node between (ord-wise) the parent node and the
child node. This simple feature returns (a reference to) an array of values.

=back

Some of the simple features can return an empty string in case they are not
applicable (eg. C<U> for the last node in the sentence), then the whole
feature is not present for the edge.

Some of the simple features return an array of values (eg. the C<B> simple
feature). This can result in several instances of the feature with the same
code for one edge to appear in the result.

=head1 FIELDS

=head2 Features

TODO: slightly outdated

The examples used here are consistent throughout this part of documentation,
i.e. if several simple features are listed in C<simple_feature_codes> and
then simple feature with index 9 is referred to in C<array_simple_features>,
it really means the C<B> simple feature which is on the 9th position in
C<simple_feature_codes>.

=over 4

=item feature_count (Int)

Alias of C<scalar @{feature_codes}> (but the integer is really
stored in the field for faster access).

=item feature_codes (ArrayRef[Str])

Codes of all features to be computed. Their
indexes in this array are used to refer to them in the code. Eg.:

 feature_codes ( [( 'L|T', 'l|t', 'L|T|l|t', 'T|B|t')] )

=item feature_codes_hash (HashRef[Str])

1 for each feature code to easily check if a feature exists

=item feature_indexes (HashRef[Str])

Index of each feature code in feature_codes (for conversion of feature code to
feature index)

=item feature_simple_features_indexes (ArrayRef[ArrayRef[Int]])

For each feature contains (a reference to) an array which contains all its
simple feature indexes (corresponding to positions in C<simple_feature_codes>
). Eg. for the 4 features (0 to 3) listed in C<feature_codes> and the 10
simple features listed in C<simple_feature_codes> (0 to 9):

 feature_simple_features_indexes ( [(
   [ (1, 5) ],
   [ (2, 6) ],
   [ (1, 5, 2, 6) ],
   [ (5, 9, 6) ],
 )] )


=item array_features (HashRef)

Indexes of features containing array simple features (see
C<array_simple_features>). Eg.:

 array_features( { 3 => 1} )

as the feature with index 3 (C<'T|B|t'>) contains the C<B> simple feature
which is an array simple feature.

=back

=head2 Simple features

=over 4

=item simple_feature_count (Int)

Alias of C<scalar @{simple_feature_codes}> (but the integer is really
stored in the field for faster access).

=item simple_feature_codes (ArrayRef[Str])

Codes of all simple features to be computed. Their order is important as their
indexes in this array are used to refer to them in the code, especially in the
C<get_simple_feature> method. Eg.:

 simple_feature_codes ( [('D', 'L', 'l', 'S', 's', 'T', 't', 'U', 'u', 'B')])

=item simple_feature_codes_hash (HashRef[Str])

1 for each simple feature code to easily check if a simple feature exists

=item simple_feature_indexes (HashRef[Str])

Index of each simple feature code in simple_feature_codes (for conversion of
simple feature code to simple feature index)

=item simple_feature_sub_arguments (ArrayRef)

For each simple feature (on the corresponsing index) contains the index of the
field (in C<field_names>), which is used to compute the simple feature value
(together with a subroutine from C<simple_feature_subs>).

If the simple feature takes more than one argument (called a multiarg feature
here), then instead of a single field index there is a reference to an array
of field indexes.

If the simple feature takes other arguments than fields (especially integers),
then these arguments are stored here insted of field indexes.

=item simple_feature_subs (ArrayRef)

For faster run, the simple features are internally not represented by their
string codes, which would have to be parsed repeatedly. Instead their codes
are parsed once only (in C<set_simple_feature>) and they are represented as
an integer index of the field which is used to compute the feature (it is the
actual index of the field in the input file line, accessible through
L<Treex::Tool::Parser::MSTperl::Node/fields>) and a reference to a subroutine
(one of the C<feature_*> subs, see below) which computes the feature value
based on the field index and the edge (L<Treex::Tool::Parser::MSTperl::Edge>).
The references subroutine is then invoked in C<get_simple_feature_values_array>.

=item array_simple_features (HashRef[Int])

Indexes of simple features that return an array of values instead of a single
string value. Eg.:

 array_simple_features( { 9 => 1} )

because in the aforementioned example the C<B> simple feature returns an array
of values and has the index C<9>.


=back

=head2 Other

=over 4

=item edge_features_cache (HashRef[ArrayRef[Str])

If caching is turned on (see below), all features of any edge computed by the
C<get_feature_simple_features_indexes> method are computed once only, stored
in this cache and then retrieved when needed.

The key of the hash is the edge signature (see
L<Treex::Tool::Parser::MSTperl::Edge/signature>), the value is
(a reference to) an array of fetures and their values.

=back

=head1 METHODS

=head2 Settings

The best source of information about all the possible settings is the
configuration file itself (usually called C<config.txt>), as it is richly
commented and accompanied by real examples at the same time.

=over 4

=item my $featuresControl =
Treex::Tool::Parser::MSTperl::FeaturesControl->new(
    'config' => $config,
    'feature_codes_from_config' => $feature_codes_array_reference,
    'use_edge_features_cache' => $use_edge_features_cache,
)

Parses feature codes and creates their in-memory representations.

=item set_feature ($feature_code)

Parses the feature code and (if no errors are encountered) creates its
representation in the fields of this package (all C<feature_>* fields and
possibly also the C<array_features> field).

=item set_simple_feature ($simple_feature_code)

Parses the simple feature code and creates its representation in the fields of
this package (all C<simple_feature_>* fields and possibly also the
C<array_simple_features> field).

=back

=head2 Computing (proper) features

=over 4

=item my $features_array_rf = $model->get_all_features($edge)

Returns (a reference to) an array which contains all features of the edge
(according to settings).

If caching is turned on, tries to look the features up in the cache before
computing them. If they are not cached yet, they are computed and stored into
the cache.

The value of a feature is computed by C<get_feature_value>. Values of simple
features are precomputed (by calling C<get_simple_feature_values_array>) and
passed to the C<get_feature_value> method.

=item my $feature_value = get_feature_value(3, $simple_feature_values)

Returns the value of the feature with the given index.

If it is an array feature (see C<array_features>), its value is (a reference
to) an array of all (string) values of the feature (a reference to an empty
array if there are no values).

If it is not an array feature, its value is composed from the simple feature
values. If some of the simple features do not have a value defined, an empty
string (C<''>) is returned.

=item my $feature_value = get_array_feature_value ($simple_features_indexes,
    $simple_feature_values, $start_from)

Recursively calls itself to compose an array of all values of the feature
(composed of the simple features given in C<$simple_features_indexes> array
reference), which is a cartesian product on all values of the simple features.
The C<$start_from> variable should be C<0> when this method is called and is
incremented in the recursive calls.

=back

=head2 Computing simple features

=over 4

=item my $simple_feature_values = get_simple_feature_values_array($edge)

Returns (a reference to) an array of values of all simple features (see
C<simple_feature_codes>). For each simple feature, its value can be found
on the position in the returned array corresponding to its position in
C<simple_feature_codes>.

=item my $sub = get_simple_feature_sub_reference ('distance')

Translates the feature funtion string name (eg. C<distance>) to its reference
(eg. C<\&feature_distance>).

=item my $value = get_simple_feature_value ($edge, 9)

Returns the value of the simple feature with the given index by calling an
appropriate C<feature_*> method on the edge
(see L<Treex::Tool::Parser::MSTperl::Edge>). If
the feature cannot be computed, an empty string (C<''>) is returned (or a
reference to an empty array for array simple features - see
C<array_simple_features>).

=item feature_distance

=item feature_child

=item feature_parent

=item feature_first

=item feature_second

=item feature_preceding_child

=item feature_preceding_parent

=item feature_following_child

=item feature_following_parent

=item feature_preceding_first

=item feature_preceding_second

=item feature_following_first

=item feature_following_second

=item feature_between

=item feature_foreach

=item feature_equals, feature_equals_pc, feature_equals_pc_at

A simple feature function C<equals(field_1,field_2)>
with "at least once" semantics for multiple values
(there can be multiple alignments)
with a special output value if one of the fields is unknown
(maybe it suffices to emmit an undef, as this would occur iff at least
one of the arguments is undef; but maybe not and eg. "-1" should be given)

This makes it possible to have a simple feature which behaves like this:

=over 4

=item returns 1 if the edge between child and parent is also present in the
English tree

=item returns 0 if not

=item returns -1 if cannot decide (alignment info is missing for some of the
nodes)

=back

Because if the parser has (the ord of the en child node and)
the ord of en child's parent and the ord of the en parent node
(and the ord of the en parent's parent), the feature can check whether
en_parent->ord = en_child->parentOrd

C<equalspc(en->ord, en->parent->ord)>

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
