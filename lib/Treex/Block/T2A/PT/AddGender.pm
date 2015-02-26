package Treex::Block::T2A::PT::AddGender;
use Moose;
use Treex::Tool::LXSuite::LXTokenizerAndTagger;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has lxsuite_key => ( isa => 'Str', is => 'ro', required => 1 );
has lxsuite_host => ( isa => 'Str', is => 'ro', required => 1 );
has lxsuite_port => ( isa => 'Int', is => 'ro', required => 1 );
has generator => ( is => 'rw' );

sub process_anode {
	my ( $self, $anode ) = @_;

	return if ($anode->lemma !~ /^[[:alpha:]]+$/);

	#TODO Handle of numerals
	return if ($anode->iset->pos !~ m/(noun|adj)/);

	my ( $forms, $lemmas, $postags, $cpostags, $feats ) = $self->generator->tokenize_and_tag(lc $anode->lemma);

	#By default the portuguese gender is set to masculine
	if ($feats->[@$feats - 1] !~ /^(m|f)/){
		log_warn $anode->lemma . " género por defeito...";
		$anode->iset->set_gender('masc');
	}
	else{

		$anode->iset->set_gender('masc') 	if ($feats->[@$feats - 1] =~ /^m/);
		$anode->iset->set_gender('fem') 	if ($feats->[@$feats - 1] =~ /^f/);
	}
	

	return;
}

sub BUILD {
    my ( $self, $argsref ) = @_;
	$self->set_generator(Treex::Tool::LXSuite::LXTokenizerAndTagger->new($argsref));
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::AddGender

=head1 DESCRIPTION

Runs the form, lemma and other attributes of a noun or adjective through the LX-Suite tagger 
extracting the gender from the resulting annotation

=head1 AUTHORS

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.



