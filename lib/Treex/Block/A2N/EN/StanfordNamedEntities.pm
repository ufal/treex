package Treex::Block::A2N::EN::StanfordNamedEntities;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '_ner' => ( is => 'rw' );
has 'model' => ( is => 'rw', isa => 'Str', default => 'ner-eng-ie.crf-3-all2008.ser.gz' );

use NER::Stanford::English;

sub process_start {
    my ($self) = @_;
    $self->_set_ner( NER::Stanford::English->new( $self->model ) );
    return;
}

Readonly my %type_for => {
    ORGANIZATION => 'i_',
    PERSON       => 'p_',
    LOCATION     => 'g_',
    O            => '0',
    NA           => '0',
};


sub process_zone {
    my ( $self, $zone ) = @_;
    my $aroot = $zone->get_atree();
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    # skip empty sentence
    return if !@anodes;

    my @words = map { $_->form } @anodes;
    my @a_ids = map { $_->id } @anodes;

    # BEWARE: $ner crashes on words like "." or "/", i.e. just punct  !!!
    my $test = join( '', @words );
    return if $test =~ /^[[:punct:]]*$/;

    # Create new n-tree (or reuse existing one)
    my $n_root = $zone->has_ntree() ? $zone->get_ntree() : $zone->create_ntree();

    # Run Standford NER
    my $types_rf = $self->_ner->tag_forms( \@words );

    # Add all found named entities to the n-tree
    my $last_type    = '0';
    my @actual_ids   = ();
    my @actual_words = ();
    foreach my $i ( 0 .. $#words ) {
        my $id   = $a_ids[$i];
        my $type = $types_rf->[$i];
        if ( $type eq 'NA' ) {
            my $form = $words[$i];

            # TODO: this is mostly caused by wrong handling of unicode in Stanford NER
            log_debug "N/A named entity type for $id '$form'";
        }

        # convert from Standford to Prague NE typology
        $type = $type_for{$type} || '0';    # conceal some warnings caused by wrong handling of numbers like "8 1/2" in Stanford NER

        # Subsequent words with the same type are treated as one named entity.
        if ( @actual_ids && $last_type ne $type ) {
            my $new_nnode = $n_root->create_child(
                ne_type => $last_type,
                normalized_name => join( ' ', @actual_words ),

            );
            $new_nnode->set_attr( 'a.rf', \@actual_ids );
            @actual_ids   = ();
            @actual_words = ();
        }
        push @actual_ids,   $id        if $type;
        push @actual_words, $words[$i] if $type;
        $last_type = $type;
    }
    if (@actual_ids) {
        my $new_nnode = $n_root->create_child(
            ne_type => $last_type,
            normalized_name => join( ' ', @actual_words ),
        );
        $new_nnode->set_attr( 'a.rf', \@actual_ids );
    }
    return 1;
}

1;

=over

=head1 NAME

Treex::Block::A2N::EN::StanfordNamedEntities - Named Entity recognition

=head1 DESCRIPTION

This block finds I<named entities> with types: person, organization, or location.
The entities are stored in n-trees.

See module L<NER::Stanford::English> for more details.

=head1 PARAMETERS

=head2 model

Filename of the model passed to L<NER::Stanford::English>

# Copyright 2009-2011 Martin Popel, David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
