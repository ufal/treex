package Treex::Block::T2T::PT2EN::MoveAdjsBeforeNouns;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_ttree {
    my ( $self, $troot ) = @_;
    foreach my $tnode ( $troot->get_descendants ) {
        my $parent = $tnode->get_parent;
        if (( $tnode->formeme || "" ) =~ /^adj:/
                and $tnode->t_lemma !~ /^(?:best|worst|greatest|great|good|fine)$/i
                and ( ( $parent->formeme || "" ) =~ /^n:/ )
                and $tnode->follows($parent)
                and not $tnode->get_children
                and not $tnode->is_member
                and not $tnode->is_parenthesis
                ) {
            my $before = $tnode->t_lemma."(".($tnode->formeme // "").") ".$parent->t_lemma."(".($parent->formeme // "").")";

            $tnode->shift_before_node($parent);

            my $after = $parent->t_lemma."(".($parent->formeme // "").") ".$tnode->t_lemma."(".($tnode->formeme // "").")";
            my $addr = $tnode->get_address();
            print STDERR "T2T::EN2PT::MoveAdjsBeforeNouns: $addr\n";
            print STDERR "T2T::EN2PT::MoveAdjsBeforeNouns: $before ==>  $after\n";
        }
    }

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::PT2EN::MoveAdjsBeforeNouns

=head1 DESCRIPTION

Adjectives (and other adjectivals) that succeed their governing nouns
are moved before them. Examples:
    política social => social policy
    Comissão Europeia => European Commission

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
