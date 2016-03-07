package Treex::Block::T2A::PT::GenerateWordforms;
use Moose;
use Treex::Core::Common;
use Treex::Tool::LXSuite;
extends 'Treex::Core::Block';

has lxsuite => ( is => 'ro', isa => 'Treex::Tool::LXSuite', default => sub { return Treex::Tool::LXSuite->new; }, required => 1, lazy => 0 );

sub _build_lxsuite {
    return Treex::Tool::LXSuite->new();
}


sub process_anode {
    my ( $self, $anode ) = @_;
    return if defined $anode->form;

    my ($tnode) = $anode->get_referencing_nodes('a/lex.rf');

    if(defined $tnode){
        if(defined $tnode->t_lemma_origin){
            if($tnode->t_lemma_origin eq 'clone'){
                $anode->set_form($tnode->t_lemma);
                return;
            }
        }
    }

    if ((defined $anode->afun) && ($anode->afun eq 'Sb')){
        print STDERR "->Warning, Afun=Sb, Lemma: ", $anode->lemma,"\n";
    }

    $anode->set_form($self->best_form_of_lemma($anode->lemma, $anode->iset));
    return;
}

my %PTFORM = (
    'ind pres' => 'pi',
    'ind past' => 'ppi',
    'ind imp'  => 'ii',
    'ind pqp'  => 'mpi',
    'ind fut'  => 'fi',
    'cnd '     => 'c',
    'sub pres' => 'pc',
    'sub imp'  => 'ic',
    'sub fut'  => 'fc',
);

my %PTNUMBER = (
    'sing' => 's',
    'plur' => 'p',
);

my %PTCATEGORY = (
    'adj' => 'ADJ',
    'noun' => 'CN',
);

my %PTGENDER = (
    'fem' => 'f',
    'masc' => 'm',
);

sub best_form_of_lemma {

    my ( $self, $lemma, $iset ) = @_;

    if ($lemma eq ""){
        log_warn "Lemma is null";
        return "null";
    }

    if ($lemma !~ /^[[:alpha:]]+$/u and $lemma ne "#PersPron"){
        log_warn "Lemma $lemma has non-alphanumeric characters";
        return $lemma;
    }

    if ($lemma =~ /_/) { return $lemma; }
    if ($lemma =~ /^(?:https?|s?ftps?):\/\//) { return $lemma; }
    if ($lemma =~ /^(?:www\.|[a-z0-9\.\-]+@[a-z0-9\-\.]+)/) { return $lemma; }

    my $pos     = $iset->pos;
    my $number  = $PTNUMBER{$iset->number} || 's';
    my $mood    = $iset->mood;
    my $tense   = $iset->tense;
    my $person  = $iset->person || '1';

    #Handle verbs
    if ($pos eq 'verb'){

        if(not $mood){ return $lemma; }

        my $form = $PTFORM{"$mood $tense"} || 'pi';

        if($mood eq 'imp'){
            $form   = 'pc';
            $person = '3';
            $number = 's';
        }

        #Passive
        if($iset->voice eq 'pass'){
            $form = 'PPT';
            $person = $PTGENDER{$iset->gender} || 'g';
        }

        my $response = $self->lxsuite->conjugate($lemma, $form, $person, $number);
        
        if(ucfirst($lemma) eq $lemma){
            $response = ucfirst($response);
        }

        #Conjugator returns with error
        return $lemma if $response eq '<NULL>';
        return $response;
    }
    #Handle nouns and adjectives
    elsif ($pos =~/^(noun|adj)$/){

        my $pos     = $PTCATEGORY{"$pos"} || 'ADJ';
        my $gender  = $PTGENDER{$iset->gender} || 'm';
        my $superlative = "false";
        my $diminutive = "false";

        if($iset->degree eq 'sup'){
            $superlative = "true";
        }

        my $response = $self->lxsuite->inflect( lc $lemma, $pos, $gender, $number, $superlative, $diminutive);

        if(ucfirst($lemma) eq $lemma){
            $response = ucfirst($response);
        }

        #Se não é permitido mudar o número não é permitido flexionar em número
        return $lemma if $response eq 'non-existing1';
        return $response;

    }

    return $lemma;

}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::PT::GenerateWordforms

=head1 DESCRIPTION

Portuguese verbal and noun/adjective conjugation through the LXSuite tools 

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
