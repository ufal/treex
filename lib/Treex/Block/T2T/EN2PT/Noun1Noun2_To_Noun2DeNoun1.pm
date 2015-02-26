package Treex::Block::T2T::EN2PT::Noun1Noun2_To_Noun2DeNoun1;
use Moose;
use Treex::Core::Common;
use LX::Data::PT;
use utf8;

extends 'Treex::Core::Block';

# say 'yes' if exists $LX::Data::PT::gentilicos{'português'};

# TODO: exceptions to this rule
# Examples:
#
#  word count -> contar palavras  ou  word count -> contagem de palavras
#




sub process_ttree {
    my ( $self, $troot ) = @_;
    foreach my $tnode ( $troot->get_descendants ) {
        my $parent = $tnode->get_parent;
        if (( $tnode->formeme || "" ) =~ /^n:(?:attr|de\+X)/ and
                (( $parent->functor || "" ) !~ /^(CONJ|COORD)$/ ) and
                (( $parent->formeme || "" ) =~ /^n:/ ) and
                $tnode->precedes($parent)) {

            my $before = $tnode->t_lemma."(".($tnode->formeme // "").") ".$parent->t_lemma."(".($parent->formeme // "").")";

            $tnode->shift_after_node($parent);
            if ($tnode->formeme =~ /^n:attr/ and
                    !exists $LX::Data::PT::gentilicos{$tnode->t_lemma}) {
                $tnode->set_formeme("n:de+X");
            }

            my $after = $parent->t_lemma."(".($parent->formeme // "").") ".$tnode->t_lemma."(".($tnode->formeme // "").")";
            my $addr = $tnode->get_address();
            print STDERR "T2T::EN2PT::Noun1Noun2_To_Noun2DeNoun1: $addr\n";
            print STDERR "T2T::EN2PT::Noun1Noun2_To_Noun2DeNoun1: $before ==>  $after\n";
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2PT::Noun1Noun2_To_Noun2DeNoun1

=head1 DESCRIPTION

Example:
    text tokenization => tokenização de texto

Exceptions:
    gentílicos:
        portuguese researcher => investigador português


=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
