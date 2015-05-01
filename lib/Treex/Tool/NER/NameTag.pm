package Treex::Tool::NER::NameTag;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use Ufal::NameTag;
with 'Treex::Tool::NER::Role';

# Path to the model data file
has model => ( is => 'ro', isa => 'Str', required => 1, writer => '_set_model' );

# Instance of Ufal::NameTag::Ner
has '_ner' => ( is=> 'rw');

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    my $model_file = Treex::Core::Resource::require_file_from_share($self->model);
    $self->_set_model($model_file);
    log_info("Loading Ufal::NameTag with model '$model_file'");
    my $ner = Ufal::NameTag::Ner::load($model_file)
        or log_fatal("Cannot load Ufal::NameTag::Ner with model from file '$model_file'");
    #log_info('Done.');
    $self->_set_ner($ner);
    return;
}

sub find_entities {
    my ( $self, $tokens_rf ) = @_;
    my $forms = Ufal::NameTag::Forms->new();
    $forms->push($_) for @$tokens_rf;

    # The main work. The result will be saved to $nametag_result.
    my $nametag_result = Ufal::NameTag::NamedEntities->new();
    $self->_ner->recognize($forms, $nametag_result);

    # Convert $nametag_result into more Perlish representation.
    # Note that $ent is a blessed empty hashref with Swig magic, so %{$ent} results in empty hash.
    my @entities;
    for my $i (0 .. $nametag_result->size-1){
        my $ent = $nametag_result->get($i);
        push @entities, {
            type => $ent->{type},
            start => $ent->{start},
            end => $ent->{start} + $ent->{length} - 1,
        };
    }

    return \@entities;
}

1;

=encoding utf-8

=head1 NAME

Treex::Tool::NER::NameTag - wrapper for Ufal::NameTag

=head1 SYNOPSIS

 use Treex::Tool::NER::NameTag;
 my $ner = Treex::Tool::NER::NameTag->new(
    model => 'data/models/nametag/cs/czech-cnec2.0-140304.ner',
 );

 my @tokens = qw(hádání Prahy s Kutnou Horou zničilo Zikmunda Lucemburského);
 my $entities_rf = $ner->find_entities(\@tokens);
 for my $entity (@$entities_rf) {
     my $entity_string = join ' ', @tokens[$entity->{start} .. $entity->{end}];
     print "type=$entity->{type} entity=$entity_string\n";
 }

=head1 DESCRIPTION

Wrapper for state-of-the-art named entity recognizer NameTag
by Milan Straka and Jana Straková.

=head1 PARAMETERS

=over

=item model

Path to the model file within Treex share.

=back

=head1 METHODS

=over

=item $entities_rf = $ner->find_entities(\@tokens);

Input: @tokens is an array of word forms (tokenized sentence).
Output: $entities_rf is a reference to an array of the recognized named entities.
Each named entity is a hash ref with keys: C<type, start, end>.
C<type> is the type of the named entity.
C<start> and <end> are (zero-based) indices to the input C<@tokens>
indicating which tokens form the given named entity.

=back

=head1 SEE ALSO

L<http://ufal.mff.cuni.cz/nametag>

L<https://metacpan.org/pod/Ufal::NameTag>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
The development of this resource is partly funded by the European Commision, project QTLeap FP7-ICT-2013.4.1-610516 L<http://qtleap.eu>

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
