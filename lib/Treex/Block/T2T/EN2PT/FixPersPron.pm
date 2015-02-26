package Treex::Block::T2T::EN2PT::FixPersPron;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
	my ( $self, $tnode ) = @_;

    my $src_tnode = $tnode->src_tnode();

    if ($src_tnode and $src_tnode->t_lemma eq "#PersPron" ) {
            my $old_t_lemma = $tnode->t_lemma;
            $tnode->set_t_lemma("#PersPron");

            if ($tnode->gram_gender eq "neut") {
                $tnode->set_gram_gender("anim");
            } 
    }

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2PT::FixPersPron

=head1 DESCRIPTION

Forces gender as anim when PersPron is neutral

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.




