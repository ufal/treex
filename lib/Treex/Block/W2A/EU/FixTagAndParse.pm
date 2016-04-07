package Treex::Block::W2A::EU::FixTagAndParse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $imperative_iset = Lingua::Interset::FeatureStructure->new({pos=> 'verb', verbform=>'fin', number=>'sing', mood=>'imp', person=>3});

sub process_anode {
    my ($self, $anode) = @_;
    my $form = $anode->form;
    my $lemma = $anode->lemma;
    
    # == Fix dependency structutre

    # == Fix lemma
    $lemma = "ukan" if ($lemma eq "*edun");
    $lemma = "edin" if ($lemma eq "*edin");
    $lemma = "ezan" if ($lemma eq "*ezan");

    # hyphen separated inflection
    if (lc($form) eq lc($lemma) && $lemma =~ s/-e?ko$//) {
	$anode->set_iset('case'=>'gen');
	$anode->set_afun('Obj');
    }

    if ($form eq $lemma && $lemma =~ s/-r?en$//) {
	$anode->set_iset('case'=>'gen');
	$anode->set_afun('Obj');
    }

    if (lc($form) eq lc($lemma) && $lemma =~ s/-a?n$//) {
	$anode->set_iset('case'=>'loc');
	$anode->set_afun('Obj');
    }

    if (lc($form) eq lc($lemma) && $lemma =~ s/-e?ra$//) {
	$anode->set_iset('case'=>'all');
	$anode->set_afun('Obj');
    }

    if (lc($form) eq lc($lemma) && $lemma =~ s/-e?k$//) {
	$anode->set_iset('case'=>'erg');
	$anode->set_afun('Obj');
    }

    if (lc($form) eq lc($lemma) && $lemma =~ s/-a$//) {
	$anode->set_iset('case'=>'abs');
	$anode->set_afun('Obj');
    }

    if (lc($form) eq lc($lemma) && $lemma =~ s/-a?ri$//) {
	$anode->set_iset('case'=>'dat');
	$anode->set_afun('Obj');
    }


    $anode->set_lemma($lemma);

    # Avoid giving a wrong lemma to integers and floats by setting the form as the lemma
    if($anode->form =~ /(\d+([\.,]\d+)*)[-\.]?\w*/){
	$anode->set_lemma($1); 
    }
    
    # == Fix iset
    if ($lemma eq "bat") {
	$anode->set_iset('pos'=>'adj', 'prontype'=>'art', 'definiteness'=>'ind', 'number'=>'sing');
	$anode->set_afun('AuxA');
    }

    # Some subjects should be actually objects
    $self->fix_false_subject($anode);  
   
    # Store other/erl in the wild dump
    my $erl = $anode->get_attr("iset/other/erl") if ($anode->iset->other);
    $anode->wild->{erl} = $erl if($erl);

    $anode->set_tag(join ' ', $anode->get_iset_values);
    return;
}




sub fix_false_subject {
    my ($self, $anode) = @_;
    return if !$anode->is_verb;
    my @children = $anode->get_echildren({or_topological=>1});
    my $subject_child = first {$_->afun eq 'Sb'} @children;
    return if !$subject_child;
    
    my $is_first_person_verb = $anode->iset->person eq '1' ? 1 : 0;
    $is_first_person_verb = 1 if $anode->is_infinitive && any {$_->iset->person eq '1' && $_->afun eq 'AuxV'} @children;
    
    if ($is_first_person_verb && $subject_child->iset->person ne '1'){
        $subject_child->set_afun('Obj');
    }
    return;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::EU::FixTagAndParse - fix IXA-Pipes errors

=head1 DESCRIPTION


=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
