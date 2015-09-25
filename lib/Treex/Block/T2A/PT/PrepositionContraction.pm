package Treex::Block::T2A::PT::PrepositionContraction;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %CONTRACTION = (
    'com si' => 'consigo',
    'de esse' => 'desse',
    'de esses' => 'desses',
    'de este' => 'deste',
    'de estes' => 'destes',
    'me as' => 'mas',
    'em o' => 'no',
    'em os' => 'nos',
    'em a' => 'na',
    'em as' => 'nas',
    'por a' => 'pela',
    'por as' => 'pelas',
    'por o' => 'pelo',
    'de entre' => 'dentre',
    'de estes' => 'destes',
    'a o' => 'ao',
    'a a' => 'à',
    'a os' => 'aos',
    'a as' => 'às',
    'a aquele' => 'àquele',
    'a aqueles' => 'àqueles',
    'a aquela' => 'àquela',
    'a aquelas' => 'àquelas',
    'aquele outro' => 'aqueloutro',
    'aqueles outros' => 'aqueloutros',
    'aquela outra' => 'aqueloutra',
    'aquelas outras' => 'aqueloutras',
    'a onde' => 'aonde',
    'com mim' => 'comigo',
    'com ti' => 'contigo',
    'com nós' => 'connosco',
    'com vós' => 'convosco',
    'de o' => 'do',
    'de os' => 'dos',
    'de a' => 'da',
    'de as' => 'das',
    'de ele' => 'dele',
    'de eles' => 'deles',
    'de ela' => 'dela',
    'de elas' => 'delas',
    'de isso' => 'disso',
    'de essa' => 'dessa',
    'de essas' => 'dessas',
    'de isto' => 'disto',
    'de esta' => 'desta',
    'de estas' => 'destas',
    'de aquele' => 'daquele',
    'de aqueles' => 'daqueles',
    'de aquela' => 'daquela',
    'de aquelas' => 'daquelas',
    'de aquilo' => 'daquilo',
    'de outrem' => 'doutrem',
    'de acolá' => 'dacolá',
    'de aí' => 'daí',
    'de além' => 'dalém',
    'de ali' => 'dali',
    'de aquém' => 'daquém',
    'de aqui' => 'daqui',
    'de outro' => 'doutro',
    'de outros' => 'doutros',
    'de outra' => 'doutra',
    'de outras' => 'doutras',
    'de onde' => 'donde',
    'em um' => 'num',
    'em uns' => 'nuns',
    'em uma' => 'numa',
    'em umas' => 'numas',
    'em isto' => 'nisto',
    'em este' => 'neste',
    'em estes' => 'nestes',
    'em esta' => 'nesta',
    'em estas' => 'nestas',
    'em isso' => 'nisso',
    'em esse' => 'nesse',
    'em esses' => 'nesses',
    'em essa' => 'nessa',
    'em essas' => 'nessas',
    'em aquilo' => 'naquilo',
    'em aquele' => 'naquele',
    'em aqueles' => 'naqueles',
    'em aquela' => 'naquela',
    'em aquelas' => 'naquelas',
    'em outrem' => 'noutrem',
    'em outro' => 'noutro',
    'em outros' => 'noutros',
    'em outra' => 'noutra',
    'em outras' => 'noutras',
    'em ele' => 'nele',
    'em eles' => 'neles',
    'em ela' => 'nela',
    'em elas' => 'nelas',
    'de algum' => 'dalgum',
    'de alguns' => 'dalguns',
    'de alguma' => 'dalguma',
    'de algumas' => 'dalgumas',
    'em algum' => 'nalgum',
    'em alguns' => 'nalguns',
    'em alguma' => 'nalguma',
    'em algumas' => 'nalgumas',
    'por os' => 'pelos',
    'me o' => 'mo',
    'me os' => 'mos',
    'me a' => 'ma',
    'te o' => 'to',
    'te os' => 'tos',
    'te a' => 'ta',
    'te as' => 'tas',
    'lhe o' => 'lho',
    'lhe os' => 'lhos',
    'lhe a' => 'lha',
    'lhe as' => 'lhas',

);

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root   = $zone->get_atree();

    my $last_node;
    foreach my $node ( $a_root->get_descendants({ ordered => 1 }) ) {

        if(defined $last_node){
            #TODO: Check this regular expression
            if( $last_node->form =~ /^[[:alpha:]]+$/){

                my $first_form = $last_node->form;
                $first_form =~ s/_//g;

                my $contraction = $CONTRACTION{(lc $first_form) . ' ' . (lc $node->form)};

                if(defined $contraction){

                    if(ucfirst($first_form) eq $first_form){
                        $last_node->set_form(ucfirst($contraction));
                    }
                    else{
                        $last_node->set_form($contraction);
                    }

                    $node->set_form('');
                    $node->set_lemma('');

                }
            }
        }

        $last_node = $node;
    }
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::PrepositionContraction

=head1 DESCRIPTION

Contracts the portuguese prepositions.

=head1 AUTHORS

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
