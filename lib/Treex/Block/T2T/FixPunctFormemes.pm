package Treex::Block::T2T::FixPunctFormemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    if (( $tnode->t_lemma || "" ) =~ /^(?:\p{P}+|-LRB-|-RRB-)$/ ) {
        $tnode->set_formeme('x');
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::FixPunctFormemes

=head1 DESCRIPTION

    Force formeme x for all punctuation tokens.


=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
