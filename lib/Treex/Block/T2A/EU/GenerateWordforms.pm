package Treex::Block::T2A::EU::GenerateWordforms;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Flect::FlectBlock';

has '+model_file' => ( default => 'data/models/flect/model-eu.pickle.Pilot3.gz');

has '+features_file' => ( default => 'data/models/flect/model-eu.features.yml' );

my $f_handle;

my $usual_errors = {"``+" => "``",
		    "botoi+noun+def+sing+abs" => "botoia",
		    "esan+verb+sing+3+3+sing+ind+pres" => "dio","esan+verb+sing+3+3+sing+ind+pres+erl" => "dioen",
		    "esan+verb+sing+3+3+plur+ind+pres" => "dio","esan+verb+sing+3+3+plur+ind+pres+erl" => "dioen",
		    "esan+verb+sing+3+ind+pres" => "dio","esan+verb+sing+3+ind+pres+erl" => "dioen",
		    
                    "izan+verb+aux+sing+1+ind+pres" => "naiz","izan+verb+aux+sing+1+ind+pres+erl" => "naizen",
		    "izan+verb+aux+sing+2+ind+pres" => "zara","izan+verb+aux+sing+2+ind+pres+erl" => "zaren",
		    "izan+verb+aux+sing+3+ind+pres" => "da","izan+verb+aux+sing+3+ind+pres+erl" => "den",
		    "izan+verb+aux+plur+1+ind+pres" => "gara","izan+verb+aux+plur+1+ind+pres+erl" => "garen",
		    "izan+verb+aux+plur+2+ind+pres" => "zarete","izan+verb+aux+plur+2+ind+pres+erl" => "zareten",
		    "izan+verb+aux+plur+3+ind+pres" => "dira","izan+verb+aux+plur+3+ind+pres+erl" => "diren",

                    "izan+verb+aux+sing+1+ind+past" => "nintzen",
		    "izan+verb+aux+sing+2+ind+past" => "zinen",
		    "izan+verb+aux+sing+3+ind+past" => "diren",
		    "izan+verb+aux+plur+1+ind+past" => "ginen",
		    "izan+verb+aux+plur+2+ind+past" => "zinete",
		    "izan+verb+aux+plur+3+ind+past" => "ziren",

                    #"izan+verb+aux+sing+1+ind+imp" => "",
		    "izan+verb+aux+sing+2+ind+imp" => "zaitez",
		    "izan+verb+aux+sing+3+ind+imp" => "bedi",
		    #"izan+verb+aux+plur+1+ind+imp" => "",
		    "izan+verb+aux+plur+2+ind+imp" => "zaitezte",
		    "izan+verb+aux+plur+3+ind+imp" => "bitez",


		    #"izan+verb+aux+sing+1+1+sing+ind+pres" => "",
		    "izan+verb+aux+sing+2+1+sing+ind+pres" => "zatzaizkit",
		    "izan+verb+aux+sing+3+1+sing+ind+pres" => "zait",
		    #"izan+verb+aux+plur+1+1+sing+ind+pres" => "",
		    "izan+verb+aux+plur+2+1+sing+ind+pres" => "zatzaizkidate",
		    "izan+verb+aux+plur+3+1+sing+ind+pres" => "zaizkit",
		    "izan+verb+aux+sing+1+2+sing+ind+pres" => "natzaizu",
		    #"izan+verb+aux+sing+2+2+sing+ind+pres" => "",
		    "izan+verb+aux+sing+3+2+sing+ind+pres" => "zaizu",
		    "izan+verb+aux+plur+1+2+sing+ind+pres" => "gatzaizkizu",
		    #"izan+verb+aux+plur+2+2+sing+ind+pres" => "",
		    "izan+verb+aux+plur+3+2+sing+ind+pres" => "zaizkizu",
		    "izan+verb+aux+sing+1+3+sing+ind+pres" => "natzaio",
		    "izan+verb+aux+sing+2+3+sing+ind+pres" => "gatzaizkio",
		    "izan+verb+aux+sing+3+3+sing+ind+pres" => "zaio",
		    "izan+verb+aux+plur+1+3+sing+ind+pres" => "zatzaizkio",
		    "izan+verb+aux+plur+2+3+sing+ind+pres" => "zatzaizkiote",
		    "izan+verb+aux+plur+3+3+sing+ind+pres" => "zaizkio",
		    #"izan+verb+aux+sing+1+1+plur+ind+pres" => "",
		    "izan+verb+aux+sing+2+1+plur+ind+pres" => "zatzaizkigu",
		    "izan+verb+aux+sing+3+1+plur+ind+pres" => "zaigu",
		    #"izan+verb+aux+plur+1+1+plur+ind+pres" => "",
		    "izan+verb+aux+plur+2+1+plur+ind+pres" => "zatzaizkigute",
		    "izan+verb+aux+plur+3+1+plur+ind+pres" => "zaizkigu",
		    "izan+verb+aux+sing+1+2+plur+ind+pres" => "natzaizue",
		    #"izan+verb+aux+sing+2+2+plur+ind+pres" => "",
		    "izan+verb+aux+sing+3+2+plur+ind+pres" => "zaizue",
		    "izan+verb+aux+plur+1+2+plur+ind+pres" => "gatzaizkizue",
		    #"izan+verb+aux+plur+2+2+plur+ind+pres" => "",
		    "izan+verb+aux+plur+3+2+plur+ind+pres" => "zaizkizue",
		    "izan+verb+aux+sing+1+3+plur+ind+pres" => "natzaie",
		    "izan+verb+aux+sing+2+3+plur+ind+pres" => "zatzaizkie",
		    "izan+verb+aux+sing+3+3+plur+ind+pres" => "zaie",
		    "izan+verb+aux+plur+1+3+plur+ind+pres" => "gatzaizkie",
		    "izan+verb+aux+plur+2+3+plur+ind+pres" => "zatzaizkiete",
		    "izan+verb+aux+plur+3+3+plur+ind+pres" => "zaizkie",


		    "ukan+verb+aux+sing+1+3+sing+ind+pres" => "dut","ukan+verb+aux+sing+1+3+sing+ind+pres+erl" => "dudan",
		    "ukan+verb+aux+sing+2+3+sing+ind+pres" => "duzu","ukan+verb+aux+sing+2+3+sing+ind+pres+erl" => "duzun",
		    "ukan+verb+aux+sing+3+3+sing+ind+pres" => "du","ukan+verb+aux+sing+3+3+sing+ind+pres+erl" => "duen",
		    "ukan+verb+aux+plur+1+3+sing+ind+pres" => "dugu","ukan+verb+aux+plur+1+3+sing+ind+pres+erl" => "dugun",
		    "ukan+verb+aux+plur+2+3+sing+ind+pres" => "duzue","ukan+verb+aux+plur+2+3+sing+ind+pres+erl" => "duzuen",
		    "ukan+verb+aux+plur+3+3+sing+ind+pres" => "dute","ukan+verb+aux+plur+3+3+sing+ind+pres+erl" => "duten",
		    "ukan+verb+aux+sing+1+3+plur+ind+pres" => "ditut","ukan+verb+aux+sing+1+3+plur+ind+pres+erl" => "ditudan",
		    "ukan+verb+aux+sing+2+3+plur+ind+pres" => "dituzu","ukan+verb+aux+sing+2+3+plur+ind+pres+erl" => "dituzun",
		    "ukan+verb+aux+sing+3+3+plur+ind+pres" => "ditu","ukan+verb+aux+sing+3+3+plur+ind+pres+erl" => "dituen",
		    "ukan+verb+aux+plur+1+3+plur+ind+pres" => "ditugu","ukan+verb+aux+plur+1+3+plur+ind+pres+erl" => "ditugun",
		    "ukan+verb+aux+plur+2+3+plur+ind+pres" => "dituzue","ukan+verb+aux+plur+2+3+plur+ind+pres+erl" => "dituzuen",
		    "ukan+verb+aux+plur+3+3+plur+ind+pres" => "dituzte","ukan+verb+aux+plur+3+3+plur+ind+pres+erl" => "dituzten",

		    "ukan+verb+aux+sing+1+3+sing+ind+past" => "nuen",
		    "ukan+verb+aux+sing+2+3+sing+ind+past" => "zenuen",
		    "ukan+verb+aux+sing+3+3+sing+ind+past" => "zuen",
		    "ukan+verb+aux+plur+1+3+sing+ind+past" => "genuen",
		    "ukan+verb+aux+plur+2+3+sing+ind+past" => "zenuten",
		    "ukan+verb+aux+plur+3+3+sing+ind+past" => "zuten",
		    "ukan+verb+aux+sing+1+3+plur+ind+past" => "nituen",
		    "ukan+verb+aux+sing+2+3+plur+ind+past" => "zenituen",
		    "ukan+verb+aux+sing+3+3+plur+ind+past" => "zituen",
		    "ukan+verb+aux+plur+1+3+plur+ind+past" => "genituen",
		    "ukan+verb+aux+plur+2+3+plur+ind+past" => "zenituzten",
		    "ukan+verb+aux+plur+3+3+plur+ind+past" => "zituzten",                    
		    #"ukan+verb+aux+sing+1+3+sing+ind+imp" => "",
		    "ukan+verb+aux+sing+2+3+sing+ind+imp" => "ezazu",
		    "ukan+verb+aux+sing+3+3+sing+ind+imp" => "beza",
		    #"ukan+verb+aux+plur+1+3+sing+ind+imp" => "",
		    "ukan+verb+aux+plur+2+3+sing+ind+imp" => "ezazue",
		    "ukan+verb+aux+plur+3+3+sing+ind+imp" => "bezate",
		    #"ukan+verb+aux+sing+1+3+plur+ind+imp" => "",
		    "ukan+verb+aux+sing+2+3+plur+ind+imp" => "itzazu",
		    "ukan+verb+aux+sing+3+3+plur+ind+imp" => "bitza",
		    #"ukan+verb+aux+plur+1+3+plur+ind+imp" => "",
		    "ukan+verb+aux+plur+2+3+plur+ind+imp" => "itzazue",
		    "ukan+verb+aux+plur+3+3+plur+ind+imp" => "bitzate",                    

		    # "ukan+verb+aux+sing+1+3+sing+ind+pres" => "",
		    # "ukan+verb+aux+sing+2+3+sing+ind+pres" => "",
		    # "ukan+verb+aux+sing+3+3+sing+ind+pres" => "",
		    # "ukan+verb+aux+plur+1+3+sing+ind+pres" => "",
		    # "ukan+verb+aux+plur+2+3+sing+ind+pres" => "",
		    # "ukan+verb+aux+plur+3+3+sing+ind+pres" => "",
		    # "ukan+verb+aux+sing+1+3+plur+ind+pres" => "",
		    # "ukan+verb+aux+sing+2+3+plur+ind+pres" => "",
		    # "ukan+verb+aux+sing+3+3+plur+ind+pres" => "",
		    # "ukan+verb+aux+plur+1+3+plur+ind+pres" => "",
		    # "ukan+verb+aux+plur+2+3+plur+ind+pres" => "",
		    # "ukan+verb+aux+plur+3+3+plur+ind+pres" => "",
                   };

#sub BUILD {
#    open($f_handle, "| sort | uniq -c | sort -rn > generation.txt");
#}

sub process_atree {
    my ( $self, $aroot ) = @_;

    my @anodes = $aroot->get_descendants( { ordered => 1 } );
    my @forms = $self->inflect_nodes(@anodes);

    for ( my $i = 0; $i < @anodes; ++$i ) {
	if (($anodes[$i]->form || "") eq "" && 
	     ($usual_errors->{$anodes[$i]->lemma."+". $anodes[$i]->tag} || "") ne "") {
	    $anodes[$i]->set_form( $usual_errors->{$anodes[$i]->lemma."+".$anodes[$i]->tag} );
	}
	if (($anodes[$i]->form || "") eq "" && ($anodes[$i]->iset->pos || "") eq "verb" &&
	    ($anodes[$i]->iset->aspect || "") eq "imp" && $anodes[$i]->lemma =~ /[td]u$/) {
	    my $form = $anodes[$i]->lemma;
	    $form =~ s/[dt]u$/tzen/;
	    $anodes[$i]->set_form($form);
	}
	if (($anodes[$i]->form || "") eq "" && (($anodes[$i]->iset->mood || "") eq "imp")) {
	    $anodes[$i]->set_form( $anodes[$i]->lemma );
	}
	if (($anodes[$i]->form || "") eq "" && (($anodes[$i]->lemma || "") =~ />/ || ($anodes[$i]->lemma || "") =~ /^xxx/)) {
	    $anodes[$i]->set_form( $anodes[$i]->lemma );
	}
	if (($anodes[$i]->form || "") eq "") {
	    $anodes[$i]->set_form( $forms[$i] );
	    #print $f_handle $anodes[$i]->lemma."+". $anodes[$i]->tag ."\t".$anodes[$i]->form."\n";
        }

    }
}

#sub DESTROY {
#    close $f_handle;
#}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::GenerateWordforms

=head1 DESCRIPTION

Generating word forms using the Flect tool. Contains pre-trained model settings for Spanish.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
