package Treex::Block::A2N::EN::StanfordNamedEntities;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );
has '_ner'      => ( is      => 'rw' );

# DOES NOT WORK YET !!!

# TODO has 'model' => (is => 'rw', isa = > 'Str', default => 'ner-eng-ie.crf-3-all2008.ser.gz');

use NER::Stanford::English;
use Readonly;

sub BUILD {
    my ($self) = @_;
    $self->_set_ner( NER::Stanford::English->new() );
    return;
}

Readonly my %type_for => {
    ORGANIZATION => 'i_',
    PERSON       => 'p_',
    LOCATION     => 'g_',
    O            => '0',
    NA           => '0',
};

#TODO: check if there is not already a SEnglishN tree.

sub process_zone {
    my ( $self, $zone ) = @_;
    my $aroot  = $zone->get_atree();
    my @anodes = $aroot->get_children();

    # skip empty sentence
    return if !@anodes;

    my @words = map { $_->form } @anodes;
    my @a_ids = map { $_->get_attr('id') } @anodes;

    # BEWARE: $ner crashes on words like "." or "/", i.e. just punct  !!!
    my $test = join( '', @words );
    return if $test =~ /^[[:punct:]]*$/;

    # Create new SEnglishN tree (just root)
    my $n_root = $zone->create_ntree();

    # Run Standford NER
    my $types_rf = $self->_ner->tag_forms( \@words );

    # Add all found named entities to the SEnglishN tree
    my $last_type    = '0';
    my @actual_ids   = ();
    my @actual_words = ();
    foreach my $i ( 0 .. $#words ) {
        my $id   = $a_ids[$i];
        my $type = $types_rf->[$i];
        if ( $type eq 'NA' ) {
            my $form = $words[$i];
            log_warn "N/A named entity type for $id '$form'";
        }

        # convert from Standford to Prague NE typology
        $type = $type_for{$type};

        # Subsequent words with the same type are treated as one named entity.
        if ( @actual_ids && $last_type ne $type ) {
            $n_root->create_child(
                {   attributes => {
                        'm.rf'          => \@actual_ids,
                        ne_type         => $last_type,
                        normalized_name => join( ' ', @actual_words ),
                        }
                }
            );
            @actual_ids   = ();
            @actual_words = ();
        }
        push @actual_ids,   $id        if $type;
        push @actual_words, $words[$i] if $type;
        $last_type = $type;
    }
    if (@actual_ids) {
        $n_root->create_child(
            {   attributes => {
                    'm.rf'          => \@actual_ids,
                    ne_type         => $last_type,
                    normalized_name => join( ' ', @actual_words ),
                    }
            }
        );
    }
    return 1;
}

1;

=over

=item Treex::Block::A2N::EN::StanfordNamedEntities

This block finds I<named entities> with types: person, organization, or location.
The entities are stored in C<SEnglishN> trees
and can be viewd with C<tmttred>, where they are projected
to m-layer, a-layer and t-layer.

Specify the model by setting the environment
variable TMT_PARAM_NER_EN_MODEL to the model file name (not the whole path).
If undefined, the default model is used and a warning is issued.

See module L<NER::Stanford::English> for more details.

=back

=cut

# Copyright 2009-2011 Martin Popel, David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
