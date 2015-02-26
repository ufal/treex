package Treex::Block::T2T::EN2PT::TurnVerbLemmaToAdjectives;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::Generation::PT::ClientLXSuite;
use Treex::Tool::LXSuite::LXConjugator;
use Treex::Tool::LXSuite::LXInflector;

has lxsuite_key => ( isa => 'Str', is => 'ro', required => 1 );
has lxsuite_host => ( isa => 'Str', is => 'ro', required => 1 );
has lxsuite_port => ( isa => 'Int', is => 'ro', required => 1 );
has [qw( _conjugator _inflector )] => ( is => 'rw' );


sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ($tnode->formeme =~ /adj/ and $tnode->t_lemma =~ /[aei]r$/) {

        my $lemma = $tnode->t_lemma;
        my $form = "PPT";
        my $person = "g";
        my $number = "s";

        my $response = $self->_conjugator->conjugate($lemma, $form, $person, $number);
        
        $response =~ /([^\/]+)\/?/;

        if ($response eq '<NULL>'){

            print STDERR "TurnVerbLemmaToAdjectives exception, $lemma not a verb?\n";
            return;
        }

        $tnode->set_t_lemma($1);
    }

    return;
}

sub BUILD {
    my $self = shift;
    my $lxconfig = {
        lxsuite_key  => $self->lxsuite_key,
        lxsuite_host => $self->lxsuite_host,
        lxsuite_port => $self->lxsuite_port,
    };
    $self->_set_conjugator(Treex::Tool::LXSuite::LXConjugator->new($lxconfig));
    $self->_set_inflector(Treex::Tool::LXSuite::LXInflector->new($lxconfig));
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



