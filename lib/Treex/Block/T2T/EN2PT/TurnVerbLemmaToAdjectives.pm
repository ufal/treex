package Treex::Block::T2T::EN2PT::TurnVerbLemmaToAdjectives;
use Moose;
use Treex::Core::Common;
use Treex::Tool::LXSuite;

extends 'Treex::Core::Block';

has lxsuite => ( is => 'ro', isa => 'Treex::Tool::LXSuite', default => sub { return Treex::Tool::LXSuite->new; }, required => 1, lazy => 0 );

sub _build_lxsuite {
    return Treex::Tool::LXSuite->new();
}

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ($tnode->formeme =~ /adj/ and $tnode->t_lemma =~ /[aei]r$/) {

        my $lemma = $tnode->t_lemma;
        my $form = "PPT";
        my $person = "g";
        my $number = "s";

        my $response = $self->lxsuite->conjugate($lemma, $form, $person, $number);
        
        $response =~ /([^\/]+)\/?/;

        if ($response eq '<NULL>'){

            print STDERR "TurnVerbLemmaToAdjectives exception, $lemma not a verb?\n";
            return;
        }

        $tnode->set_t_lemma($1);
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2PT::TurnVerbLemmaToAdjectives

=head1 DESCRIPTION

Corrects verb nodes lemma with wrong formeme (adj) by passing through the LX-Suite conjugator
as a past participle

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.



