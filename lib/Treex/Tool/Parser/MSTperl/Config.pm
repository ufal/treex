package Treex::Tool::Parser::MSTperl::Config;

use Moose;
use autodie;
use Carp;
use File::Spec;

use Treex::Tool::Parser::MSTperl::FeaturesControl;
use Treex::Tool::Parser::MSTperl::ModelAdditional;

# varied levels of debug info,
# ranging from 0 (no debug info)
# through 1 (progress messages - this is the default setting)
# through 2, 3 and 4 to 5 (more and more debug info)
has 'DEBUG' => (
    is      => 'rw',
    isa     => 'Int',
    default => '1',
);

# Viterbi settings

has 'SEQUENCE_BOUNDARY_LABEL' => (
    is      => 'rw',
    isa     => 'Str',
    default => '###',
);

has 'VITERBI_STATES_NUM_THRESHOLD' => (
    is      => 'rw',
    isa     => 'Int',
    default => 5,
);

# stopping criterion of EM algorithm (when the sum of change of smoothing
# parameters is lower than the epsilon, the algorithm stops)
has 'EM_EPSILON' => (
    is      => 'rw',
    isa     => 'Num',
    default => 0.00001,
);

# strmost sigmoidy
has 'SIGM_LAMBDA' => (
    is  => 'rw',
    isa => 'Num',

    #    default => 0.0015, probably good for data as they used to be :-)
    default => 1,
);

# added to emission probs to make them non-negative
# has 'EMISSIONS_SHIFT' => (
#     is      => 'rw',
#     isa     => 'Int',
#     default => 500,
# );

# where in training data do heldout data for EM algorithm start
# (a number between 0 and 1, eg. 0.75 means that first 75% of sentences
#  are training data and the last 25% are heldout data)
has 'EM_heldout_data_at' => (
    is      => 'rw',
    isa     => 'Num',
    default => 0.9,
);

has 'config_file' => (
    is       => 'ro',
    isa      => 'Str',
    required => '1',
);

has 'unlabelledFeaturesControl' => (
    isa => 'Maybe[Treex::Tool::Parser::MSTperl::FeaturesControl]',
    is  => 'rw',
);

has 'labelledFeaturesControl' => (
    isa => 'Maybe[Treex::Tool::Parser::MSTperl::FeaturesControl]',
    is  => 'rw',
);

# has 'imlabelledFeaturesControl' => (
#     isa => 'Maybe[Treex::Tool::Parser::MSTperl::FeaturesControl]',
#     is  => 'rw',
# );

# CONFIGURATION

# only assigning is_member (as opposed to afun labelling)
# has 'is_member_labelling' => (
#     is      => 'ro',
#     isa     => 'Bool',
#     default => '0',
# );

# training mode or parsing mode
has 'training' => (
    is      => 'ro',
    isa     => 'Bool',
    default => '0',
);

# (default is parsing mode)

# has 'ord_field_index' => (
#     is => 'rw',
#     isa => 'Int',
# );

# just temporary before it is found out
# which algorithm is the best one
has 'labeller_algorithm' => (
    is      => 'rw',
    isa     => 'Int',
    default => '0',
);

has 'parent_ord' => (
    is      => 'rw',
    isa     => 'Str',
    trigger => \&_parent_ord_set,
);

# sets parent_ord_field_index
sub _parent_ord_set {
    my ( $self, $parent_ord ) = @_;

    # set index of parent's ord field
    my $parent_ord_index = $self->field_name2index($parent_ord);
    $self->parent_ord_field_index($parent_ord_index);

    return;
}

has 'parent_ord_field_index' => (
    is  => 'rw',
    isa => 'Int',
);

has 'label' => (
    is      => 'rw',
    isa     => 'Str',
    trigger => \&_label_set,
);

# sets label_field_index
sub _label_set {
    my ( $self, $label ) = @_;

    # set index of label field
    my $label_index = $self->field_name2index($label);
    $self->label_field_index($label_index);

    return;
}

has 'label_field_index' => (
    is  => 'rw',
    isa => 'Maybe[Int]',

    #    default => 'undef',
);

# has 'ismember' => (
#     is      => 'rw',
#     isa     => 'Str',
#     trigger => \&_ismember_set,
# );

# sets ismember_field_index
# sub _ismember_set {
#     my ( $self, $ismember ) = @_;
#
#     # set index of ismember field
#     my $ismember_index = $self->field_name2index($ismember);
#     $self->ismember_field_index($ismember_index);
#
#     return;
# }

# has 'ismember_field_index' => (
#     is  => 'rw',
#     isa => 'Maybe[Int]',
#
#     #    default => 'undef',
# );

has 'root_field_values' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    trigger => \&_root_field_values_set,
);

# checks number of root field values
sub _root_field_values_set {
    my ($self) = @_;

    # check number of fields
    my $root_fields_count = scalar( @{ $self->root_field_values } );
    if ( $root_fields_count != $self->field_names_count ) {
        croak "MSTperl config file error: " .
            "Incorrect number of root field values ($root_fields_count), " .
            "must be same as number of field names (" .
            $self->field_names_count . ")!";
    }

    return;
}

has 'number_of_iterations' => (
    isa     => 'Int',
    is      => 'rw',
    default => 3,
);

has 'labeller_number_of_iterations' => (
    isa     => 'Int',
    is      => 'rw',
    default => 3,
);

# has 'imlabeller_number_of_iterations' => (
#     isa     => 'Int',
#     is      => 'rw',
#     default => 3,
# );

has 'use_edge_features_cache' => (
    is      => 'rw',
    isa     => 'Bool',
    default => '0',
);

has 'labeller_use_edge_features_cache' => (
    is      => 'rw',
    isa     => 'Bool',
    default => '0',
);

# has 'imlabeller_use_edge_features_cache' => (
#     is      => 'rw',
#     isa     => 'Bool',
#     default => '0',
# );

# using cache turned off to fit into RAM by default
# turn on if training with a lot of RAM or on small training data
# turned off when parsing (does not make any sense for parsing)

# Distance buckets

has 'distance_buckets' => (
    is      => 'rw',
    isa     => 'ArrayRef[Int]',
    default => sub { [] },
    trigger => \&_distance_buckets_set,
);

# sets distance2bucket, maxBucket and minBucket
sub _distance_buckets_set {
    my ( $self, $distance_buckets ) = @_;

    my %distance2bucket;

    # find maximal bucket & partly fill %distance2bucket
    my $maxBucket = 0;
    foreach my $bucket ( @{$distance_buckets} ) {
        if ( $distance2bucket{$bucket} ) {
            warn "Bucket '$bucket' is defined more than once; " .
                "disregarding its later definitions.\n";
        } elsif ( $bucket <= 0 ) {
            croak "MSTperl config file error: " .
                "Error on bucket '$bucket' - " .
                "buckets must be positive integers.";
        } else {
            $distance2bucket{$bucket} = $bucket;
            $distance2bucket{ -$bucket } = -$bucket;
            if ( $bucket > $maxBucket ) {
                $maxBucket = $bucket;
            }
        }
    }

    # set maxBucket and minBucket
    my $minBucket = -$maxBucket;
    $self->maxBucket($maxBucket);
    $self->minBucket($minBucket);

    # fill %distance2bucket from minBucket to maxBucket
    if ( !$distance2bucket{1} ) {
        warn "Bucket '1' is not defined, which does not make any sense; " .
            "adding definition of bucket '1'.\n";
        $distance2bucket{1}  = 1;
        $distance2bucket{-1} = -1;
    }
    my $lastBucket = 1;
    for ( my $distance = 2; $distance < $maxBucket; $distance++ ) {
        if ( $distance2bucket{$distance} ) {

            # the distance defines a bucket
            $lastBucket = $distance2bucket{$distance};
        } else {

            # the distance falls into the highest lower bucket
            $distance2bucket{$distance} = $lastBucket;
            $distance2bucket{ -$distance } = -$lastBucket;
        }
    }
    $self->distance2bucket( \%distance2bucket );

    return;
}

has 'distance2bucket' => (
    is      => 'rw',
    isa     => 'HashRef[Int]',
    default => sub { {} },
);

# if mapping is not found in the hash, maxBucket or minBucket is used

has 'maxBucket' => (
    isa     => 'Int',
    is      => 'rw',
    default => '9',
);

# any higher distance falls into this bucket

has 'minBucket' => (
    isa     => 'Int',
    is      => 'rw',
    default => '-9',
);

# any lower distance falls into this bucket, distance is signed (ORD minus ord)

# FIELDS

# field names (for conversion of field index to field name)
has 'field_names' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    trigger => \&_field_names_set,
);

# checks field_names, sets field_names_hash and field_indexes
sub _field_names_set {
    my ( $self, $field_names ) = @_;

    my %field_names_hash;
    my %field_indexes;
    for ( my $index = 0; $index < scalar( @{$field_names} ); $index++ ) {
        my $field_name = $field_names->[$index];
        if ( $field_names_hash{$field_name} ) {
            croak "MSTperl config file error: " .
                "Duplicate field name '$field_name'!";
        } elsif ( $field_name ne lc($field_name) ) {
            croak "MSTperl config file error: " .
                "Field name '$field_name' is not lowercase!";
        } elsif ( !$field_name =~ /a-z/ ) {
            croak "MSTperl config file error: " .
                "Field name '$field_name' does not contain " .
                "any character from [a-z]!";
        } else {
            $field_names_hash{$field_name} = 1;
            $field_indexes{$field_name}    = $index;
        }
    }

    $self->field_names_count( scalar( @{$field_names} ) );
    $self->field_names_hash( \%field_names_hash );
    $self->field_indexes( \%field_indexes );

    return;
}

has 'field_names_count' => (
    is      => 'rw',
    isa     => 'Int',
    default => '0',
);

# 1 for each field name to easily check if a field name exists
has 'field_names_hash' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

# index of each field name in field_names
# (for conversion of field name to field index)
has 'field_indexes' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
);

has lossFunction => ( is => 'rw', isa => 'Str', default => '' );

has use_pmi => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0
);

has pmi_model_file => (
    is      => 'rw',
    isa     => 'Str',
    default => ''
);

has pmi_model_format => (
    is      => 'rw',
    isa     => 'Str',
    default => 'tsv'
);

has 'pmi_buckets' => (
    is      => 'rw',
    isa     => 'Maybe[ArrayRef[Int]]',
    default => undef,
);

has use_cprob => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0
);

has cprob_model_file => (
    is      => 'rw',
    isa     => 'Str',
    default => ''
);

has cprob_model_format => (
    is      => 'rw',
    isa     => 'Str',
    default => 'tsv'
);

has 'cprob_buckets' => (
    is      => 'rw',
    isa     => 'Maybe[ArrayRef[Int]]',
    default => undef,
);

has 'baseline_parse' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has 'baseline_parse_type' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'left-branching',
);

has 'normalization_type' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'divabssum',
);

# By default tries to load everything immediately.
# If set to 1, will let the invoker call load() whenever appropriate.
# Designed for fixing filenames from the outside.
has lazyload => ( is => 'rw', isa => 'Bool', default => 0 );

# METHODS

sub BUILD {
    my ($self) = @_;

    if ( $self->DEBUG >= 1 ) {
        print "Processing config file " . $self->config_file . "...\n";
    }

    # check if file exists
    unless ( -e $self->config_file ) {
        my $dir;
        my ( $volume, $directory, $cfile ) =
            File::Spec->splitpath( $self->config_file );
        $dir = File::Spec->catpath( $volume, $directory, '' );
        my @files = ();
        opendir( my $dirhandle, $dir ) or croak $!;
        while ( my $file = readdir($dirhandle) ) {
            push @files, $file;
        }
        closedir($dirhandle);
        croak "The config file $cfile does not exists!\n" .
            "The directory $dir contains the following files: " .
            join ', ', @files;
    }
    use YAML::Tiny;
    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( $self->config_file );

    if ( !$config ) {
        croak "MSTperl config file error: " . YAML::Tiny->errstr;

    } else {

        # fields to set, in the order in which they are to be set
        my @fields = (
            'field_names',
            'root_field_values',
            'parent_ord',
            'distance_buckets',
            'label',
            'lossFunction',
            'use_pmi',
            'pmi_model_file',
            'pmi_model_format',
            'pmi_buckets',
            'use_cprob',
            'cprob_model_file',
            'cprob_model_format',
            'cprob_buckets',
            'use_edge_features_cache',
            'labeller_use_edge_features_cache',
            'number_of_iterations',
            'labeller_number_of_iterations',
            'labeller_algorithm',
            'DEBUG',
            'SEQUENCE_BOUNDARY_LABEL',
            'VITERBI_STATES_NUM_THRESHOLD',
            'EM_EPSILON',
            'EM_heldout_data_at',
            'baseline_parse',
            'baseline_parse_type',
            'normalization_type',
        );

        # name => required?
        my %required_fields = (
            'field_names'       => 1,
            'root_field_values' => 1,
            'parent_ord'        => 1,
            'distance_buckets'  => 1,
        );
        foreach my $field (@fields) {
            if ( $config->[0]->{$field} ) {
                $self->$field( $config->[0]->{$field} );
            } else {

                # if required, then croak
                if ( $required_fields{$field} ) {
                    croak "MSTperl config file error:"
                        . "Field $field must be set!";
                }

                # else OK (default value will be used)
            }
        }

        # ignore some settings if in parsing-only mode
        if ( !$self->training ) {
            $self->use_edge_features_cache(0);
            $self->labeller_use_edge_features_cache(0);
        }

        # unlabelled features
        if ( $config->[0]->{features} && @{ $config->[0]->{features} } ) {
            $self->unlabelledFeaturesControl(
                Treex::Tool::Parser::MSTperl::FeaturesControl->new(
                    'config'                    => $self,
                    'feature_codes_from_config' => $config->[0]->{features},
                    'use_edge_features_cache'
                        => $self->use_edge_features_cache,
                    )
            );
        }

        # labeller features
        if ($config->[0]->{labeller_features}
            && @{ $config->[0]->{labeller_features} }
            )
        {
            $self->labelledFeaturesControl(
                Treex::Tool::Parser::MSTperl::FeaturesControl->new(
                    'config' => $self,
                    'feature_codes_from_config'
                        => $config->[0]->{labeller_features},
                    'use_edge_features_cache'
                        => $self->labeller_use_edge_features_cache,
                    )
            );
        }

        # imlabeller features
        #         if ($config->[0]->{imlabeller_features}
        #             && @{ $config->[0]->{imlabeller_features} }
        #             )
        #         {
        #             $self->imlabelledFeaturesControl(
        #                 Treex::Tool::Parser::MSTperl::FeaturesControl->new(
        #                     'config' => $self,
        #                     'feature_codes_from_config'
        #                         => $config->[0]->{imlabeller_features},
        #                     'use_edge_features_cache'
        #                         => $self->imlabeller_use_edge_features_cache,
        #                     )
        #             );
        #         }

        if (!$self->unlabelledFeaturesControl
            && !$self->labelledFeaturesControl
            && !$self->baseline_parse
            #             && !$self->imlabelledFeaturesControl
            )
        {
            croak "MSTperl config file error: No features set!";
        }

        if ( !$self->lazyload ) {
            $self->load();
        }

    }

    if ( $self->DEBUG >= 1 ) {
        print "Done." . "\n";
    }

    return;
}

sub load {
    my ($self) = @_;

    if ( $self->use_pmi ) {
        my $pmi_model = Treex::Tool::Parser::MSTperl::ModelAdditional->new(
            config       => $self,
            model_file   => $self->pmi_model_file,
            model_format => $self->pmi_model_format,
            buckets      => $self->pmi_buckets,
        );
        my $result = $pmi_model->load();
        if ($result) {
            $self->unlabelledFeaturesControl->pmi_model($pmi_model);
        }
    }

    if ( $self->use_cprob ) {
        my $cprob_model = Treex::Tool::Parser::MSTperl::ModelAdditional->new(
            config       => $self,
            model_file   => $self->cprob_model_file,
            model_format => $self->cprob_model_format,
            buckets      => $self->cprob_buckets,
        );
        my $result = $cprob_model->load();
        if ($result) {
            $self->unlabelledFeaturesControl->cprob_model($cprob_model);
        }
    }

    return;
}

sub field_name2index {
    my ( $self, $field_name ) = @_;

    if ( ref $field_name eq 'ARRAY' ) {

        # multiarg feature
        my @return;
        foreach my $field ( @{$field_name} ) {
            push @return, $self->field_name2index($field);
        }
        return [@return];
    } else {
        if ( $self->field_names_hash->{$field_name} ) {

            # everything OK -> return the field name
            return $self->field_indexes->{$field_name};
        } elsif ( $field_name =~ /^-?[0-9]+$/ ) {

            # not an actual field name but an integer argument -> keep it
            return $field_name;
        } else {
            croak "Unknown field '$field_name', quiting.";
        }
    }
}

1;

__END__









=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::Config

=head1 DESCRIPTION

Handles the configuration of the parser.

=head1 FIELDS

=head2 Data fields

Fields describing fields used with nodes, such as form, pos, lemma...

=over 4

=item field_names (ArrayRef[Str])

Field names (for conversion of field index to field name)

=item field_names_hash (HashRef[Str])

1 for each field name to easily check if a field name exists

=item field_indexes (HashRef[Str])

Index of each field name in field_names (for conversion of field name to field
index)

=back

=head2 Settings

Most of the settings are set by a config file in YAML format.
However, you do not have to understand YAML to be able to change the
settings provided that you keep things like formating of the file unchanged
(some whitespaces are significant etc.). Actually only a subset of all
all that YAML provides is used.

Contents of a line from the # character till the end of the line are comments
and are ignored (if you need to actually use the # sign, you can quote it -
eg. C<'#empty#'> is interpreted as C<#empty#>). Lines that contain only
whitespace chars or are empty are ignored as well.

Some of the settings are ignored when in parsing mode (i.e. not training).
These are use_edge_features_cache (turned off) and number_of_iterations
(irrelevant).

These are settings which are acquired from the configuration file:

=head3 Required Settings

=over 4

=item field_names

Lowercase names of fields in the input file
(the data fields are to be separated by tabs in the input file).
Use [a-z0-9_] only, using always at least one letter.
Use unique names, i.e. devise some names even for unused fields.

=item root_field_values

Field values to set for the (technical) root node.

=item parent_ord

Name of field containing ord of the parent of the node
(also called "head" or "governing node").

=item distance_buckets

Buckets to use for C<distance()> function (positive integers in any order).
Each distance gets bucketed in the highest lower bucket (absolute-value-wise).

Default:

 distance_buckets:
  - 1
  - 2
  - 3
  - 4
  - 5
  - 11

=back

=head3 Features Settings

Features to be computed on data.

Features for the unlabelled parser are set under C<features>,
the labeller features under C<labeller_features>.

Use the (lowercase) input file field names (e.g. C<pos>)
to use the field of the (child) node,
uppercase them (e.g. C<POS>) to use the field of the parent,
joined together by the C<|> sign to form the features (e.g. C<POS|LEMMA>).

Prefix the field names by C<1.> or C<2.>
to use the field on the first or second node in the sentence - based on
their order in the sentence, regardless of which is parent and which is child
(e.g. C<1.pos> for pos of first of the nodes).

There are also several predefined functions that you can make use of.
Usually you can write the function name in lowercase to invoke them on the child
field, uppercase for parent, or prefixed by C<1.> or C<2.> for first or second
node (e.g. C<CHILDNO()> to get the number of parent node's children). The
parameter of a function must be a (child) field name, or an integer (as the
C<index> in C<equalspcat>).

=over 4

=item distance()

bucketed ord-wise distance of child and parent: C<ORD> minus C<ord>

=item attdir()

parent - child attachement direction: C<signum(ORD minus ord)>

=item preceding(field)

value of the specified field on the ord-wise preceding node
(use C<PRECEDING(field)> to get field on node preceding the PARENT)

=item following(field)

value of the specified field on the ord-wise following node

=item between(field)

value of the specified field for each node which is ord-wise between the child
node and the parent node

=item equals(field1,field2)

Returns C<1> if the value of C<field1> is the same as
the value of C<field2>. For fields with multiple values,
it has the meaning of an "exists" operator: it returns
C<1> if there is at least one pair of values of each field that are
the same.

Returns C<0> if the values don't match.

Returns C<-1> if (at least) one of the vaues is
C<undef> (may be also represented by an empty string)

=item equalspc(field1,field2)

like C<equals> but C<field1> is taken from parent node
and C<field2> from child node

=item equalspcat(field,position)

like C<equalspc> but looks at the given position (1 character)
in the given field

=item substr(field,start,length)

substring of field value beginning at given
start position (0-based) of given length; standard substr behaviour,
i.e. both start and length can be negative and length can be omitted,
feature function to be then written as C<substr(field,start)>

=item arrayat(array_field,index_field)

array_field's value is an array of values
separated by single spaces (' '), index_field's value is a zero-based
index of a value in the array to be returned (used e.g. for tree distance)

=item isfirst()

returns 1 if node is the first in the sentence, 0 otherwise

=item islast()

returns C<1> if node is the last in the sentence, C<0> otherwise

=item isfirstchild()

returns C<1> if node is the first child of its parent, C<0> otherwise

=item islastchild()

returns C<1> if node is the last child of its parent, C<0> otherwise

=item childno()

returns number of node's children

=item islastleftchild()

is the rightmost of all left children of its parent

=item isfirstrightchild()

is the leftmost of all right children of its parent

=item LABEL()

label of parent (to be used only in labeller features);
label is somewhat special, it cannot be used as C<label>, C<LABEL> or C<label()>

Features containing the C<LABEL()> function are dynamic, i.e. they cannot be
precomputed and are always computed just at the time they are needed.

=item prevlabel()

label of previous sibling (to be used only in labeller features);
prevlabel is somewhat special, it cannot be used as
C<prevlabel>, C<PREVLABEL> or C<PREVLABEL()>

Features containing the C<prevlabel()> function are dynamic, i.e. they cannot be
precomputed and are always computed just at the time they are needed.

=back

See also L<Treex::Tool::Parser::MSTperl::FeaturesControl>.

=head3 Internal technical settings

These settings are probably better left as they are, but it might be
advantageous to have the ability of changing them sometimes, especially when
experimenting.

You can set the values in various ways. The order of priorities is:

=over 4

=item 1 set in runtime

i.e. set after having created a new Config object:

 my $config = Treex::Tool::Parser::MSTperl::Config->new(
    config_file => 'my_config.config');
 $config->DEBUG(4);

The value is only valid from the time of setting.

=item 2 set in config file

in my_config.config:

 DEBUG: 4

in the perl script:

 my $config = Treex::Tool::Parser::MSTperl::Config->new(
    config_file => 'my_config.config');

=item 3 set in the constructor

i.e. set while creating a new Config object:

in my_config.config:

 # DEBUG: 0

in the perl script:

 my $config = Treex::Tool::Parser::MSTperl::Config->new(
    config_file => 'my_config.config',
    DEBUG => 4 );

For the setting to take effect, you must not set another value in the config
file (you can comment out setting it with '#').

=item 4 the default value

Used if the value is not set in runtime, in constructor or in the config file.

=back

Please note that setting some of the values at runtime might not be a good idea.

The options are listed here together with their defaults.

=over 4

=item DEBUG: 0

An integer specifying how much debug information you will be getting while
running the program, ranging from 0 (no debug info)
through 1 (progress messages)
through 2, 3 and 4 to 5 (more and more debug info).

If you set this value to something higher than 1, you should always redirect
the output to a file as printing it to the console is very very slow
(and there is so much info that you wouldn't be able to
read anything anyway).

The possibility
to change the value
while running the program
might be beneficial
e.g. if you only want to debug only a particular
part of the program.

=item number_of_iterations: 3, labeller_number_of_iterations: 3

How many times the trainer (Tagger::MSTperl::Trainer) should go through
all the training data.

=item use_edge_features_cache: 0, labeller_use_edge_features_cache: 0

Currently deprecated, unmaintained and probably to be removed.

Turns on and off using the C<edge_features_cache>.

Using cache should be turned on (C<1>) if training with a lot of RAM or on small
training data, as it uses a lot of memory but speeds up the training greatly
(approx. by 30% to 50%). If you need to save RAM, turn it off (C<0>).

=item labeller_algorithm: 16

Algorithm used for Viterbi labelling as well as for training. Several
possibilities were tried out,
especially regarding the emission probabilities used in the Viterbi algorithm;
this is for development purposes only, preferebly do not use.

=over

=item (0) MIRA-trained weights

recomputed by +abs(min) and converted to probs,
transitions by MLE on labels

=item (1) dtto, NOT converted to probs

should be same as 0

=item (2) dtto, sum in Viterbi instead of product

new_prob = old_prob + emiss*trans

=item (3) dtto, no recompution

just strip <= 0

=item (4) basic MLE

no MIRA, no smoothing, uniform feature weights
blind (unigram) transition backoff,
blind emission backoff (but should not be necessary)

=item (5) full Viterbi

dtto, transition probs lambda smoothing by EM

=item (8) MIRA for all

completely new, based on reading, no MLE, MIRA for all,
same features for label unigrams and label bigrams

=item (9) dtto, initialize emissions and transitions by MLE

=item (10)  0 + fixed best state selection

=item (11) 10 + tries to use all possible labels

=item (12) 10 + EM for smoothing of transitions

=item (13) 11 + EM for smoothing of transitions

=item (14) 10 + update uses transition probs as well

=item (15) 12 + update uses transition probs as well

=item (16)  8 + transitions by MLE & EM on label pairs

multiplied with emission score in Viterbi and added to last state score

=item (17)  dtto, different transition computation for negative scores

=item (18) 16 + no Viterbi summing

=item (19) 16, better formula for combining emissions and transitions

=item (20) MIRA for all

=item (21) MIRA for all, with Viterbi

=item (22) MIRA for all, sentence = one sequence (disregarding tree structure)

=back

=item SEQUENCE_BOUNDARY_LABEL: '###'

This is only a technical thing; a label must be assigned to the (basically
virtual) boundary of a sequence, different from any label used in the data.
The default value is '###', so if you use this exact label as a valid label in
your data, change the setting to something else. If nothing goes wrong, you
should never see this label in the output; however, it is contained in the
model and used for "transition scores" to score the "transition" between the
sequence boundary and the first/last node (i.e. it determines the scores of
labels used as the first or last label in the sequence where no actual
transition takes place and the transition scores would otherwise get ignored).

=item VITERBI_STATES_NUM_THRESHOLD

Number of states to keep when pruning. The pruning takes place after each
Viterbi step (i.e. after each computation of possible labels and their scores
for one edge). For more details see the C<prune> subroutine.

=item EM_EPSILON: 0.00001

Stopping criterion of EM algorithm which is used to compute smoothing
parameters for linear combination smoothing of transition probabilities
in some variants of the Labeller.
(when the sum of change of smoothing
parameters is lower than the epsilon, the algorithm stops).

=item EM_heldout_data_at: 0.9

A number between 0 and 1 specifying
where in training data do heldout data for EM algorithm start
(eg. 0.75 means that first 75% of sentences
are training data and the last 25% are heldout data).

The training/heldout data division only affects computation of transition
probabilities by MLE, it does not affect MIRA training or MLE for emission
probabilities.

If EM is not used for smoothing, all data are used as training data.

=back

=head2 Technical fields

Provide access to things needed in more than one of the other packages.

=over 4

=item unlabelledFeaturesControl

Provides access to unlabelled features, especially enabling their computation.
Intance of L<Treex::Tool::Parser::MSTperl::FeaturesControl>.

=item labelledFeaturesControl

Provides access to labeller features, especially enabling their computation.
Intance of L<Treex::Tool::Parser::MSTperl::FeaturesControl>.

=back

=head1 METHODS

=head2 Settings

The best source of information about all the possible settings is the
configuration file itself (usually called C<config.txt>), as it is richly
commented and accompanied by real examples at the same time.

=over 4

=item my $config =
Treex::Tool::Parser::MSTperl::Config->new(config_file => 'file.config')

Reads the configuration file (in YAML format) and applies the settings.

See file C<samples/sample.config>.

=item field_name2index ($field_name)

Fields are referred to by names in the config files but by indexes in the
code. Therefore this conversion function is necessary; the other direction of
the conversion is ensured by the C<field_names> field.

=back


=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
