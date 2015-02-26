package Treex::Block::T2T::EN2PT::FixPunctuation;
use Moose;
use Treex::Core::Common;
use utf8;

extends 'Treex::Core::Block';

sub process_tnode {
	my ( $self, $tnode ) = @_;

    my $src_tnode = $tnode->src_tnode();

    if ($src_tnode and $src_tnode->t_lemma  =~ /^[<>]$/) {
            $tnode->set_formeme('x');
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2PT::FixPunctuation

=head1 DESCRIPTION

Fixes the greater > and lesser < symbol with a 'x' formeme

=head1 AUTHORS

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


