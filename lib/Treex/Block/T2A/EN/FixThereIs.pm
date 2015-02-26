package Treex::Block::T2A::EN::FixThereIs;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ($tnode->wild->{there_is}) {
        my ($tsubject) = grep {$_->t_lemma eq "#PersPron" and $_->formeme eq "n:subj"} $tnode->get_children;
        if ($tsubject) {
            my $asubject = $tsubject->get_lex_anode;
            if ($asubject) {
                $asubject->set_form("there");
            }
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::FixThereIs

=head1 DESCRIPTION



=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

Copyright © 2014 by NLX Group, Universidade de Lisboa

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.