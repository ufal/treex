package Treex::Scen::MLFix::WriteTriparallel;

use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

has language => (
	is			=> 'ro',
	isa			=> 'Treex::Type::LangCode',
	required	=> 1
);

sub BUILD {
	my ($self) = @_;

	return;
}

sub get_scenario_string {
	my ($self) = @_;

	my $language = $self->language;

	my $scen = join "\n",
        "Util::SetGlobal language=$language selector=",
        "A2W::Detokenize",

        $language eq "cs" ? "A2W::CS::DetokenizeUsingRules" : (),
        $language eq "cs" ? "A2W::CS::DetokenizeDashes" : (),
        
        'Util::Eval bundle=\'
            my $src_tree = $bundle->get_zone( "en", "" )->get_atree();
            my $mt_tree = $bundle->get_zone( "'.$language.'", "T" )->get_atree();
            my $ref_tree = $bundle->get_zone( "'.$language.'", "ref" )->get_atree();
            print 
            join( " ", map {$_->form . "|" . $_->lemma} $src_tree->get_descendants( { ordered => 1} ) ) . "\t" .
            join( " ", map {$_->form . "|" . $_->lemma} $mt_tree->get_descendants( { ordered => 1} ) ) . "\t" .
            join( " ", map {$_->form . "|" . $_->lemma} $ref_tree->get_descendants( { ordered => 1} ) )
             . "\n";\'';

	return $scen;
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Scen::MLFix::WriteSentences - Detokenize and write fixed sentences

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
