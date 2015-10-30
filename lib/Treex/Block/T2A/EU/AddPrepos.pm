package Treex::Block::T2A::EU::AddPrepos;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddPrepos';

use utf8;


# In Spanish, it seems adverbs may have prepositions as well (e.g. "por allí").
has '+formeme_prep_regexp' => ( default => '^(?:n|adj|adv):(.+)[+]' );

my $CASES = "^(nom|gen|dat|acc|voc|loc|ins|abl|par|dis|ess|tra|com|abe|ine|ela|ill|add|ade|all|sub|sup|del|lat|tem|ter|abs|erg|cau|ben)\$";

override 'process_tnode' => sub {
    my ( $self, $tnode ) = @_;
    my $prep_forms_string = $self->get_prep_forms($tnode->formeme);
    my $anode = $tnode->get_lex_anode();

    # Skip weird t-nodes with no lex_anode and nodes with no prepositions to add
    return if (!defined $anode or !$prep_forms_string);

    # Occasionally there may be more than one preposition (e.g. na_rozdíl_od)
    my @prep_forms = split /_/, $prep_forms_string;

    # Create new nodes for all prepositions.
    # Put them before $anode's subtree (in right word order)
    my @prep_nodes;

    my @subnodes = grep{$_->formeme =~ /^(n|adj):attr/} $tnode->get_children({ ordered => 1});
    my $nodeaux = $anode;

    $nodeaux = @subnodes[-1]->get_lex_anode() if(@subnodes);

    $nodeaux->iset->add("case" => "$prep_forms[-1]") if (defined $prep_forms[-1] && $prep_forms[-1] =~ /$CASES/);

    # Language-specific stuff to go here
    $self->postprocess($tnode, $anode, $prep_forms_string, \@prep_nodes);

    return;
};


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::AddPrepos

=head1 DESCRIPTION

Adding prepositional a-nodes according to prepositions contained in t-nodes' formemes.
In Spanish, it seems adverbs may have prepositions as well (e.g. "por allí").

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
