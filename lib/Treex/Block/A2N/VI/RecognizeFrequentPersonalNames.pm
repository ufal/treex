package Treex::Block::A2N::VI::RecognizeFrequentPersonalNames;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::CS;

extends 'Treex::Core::Block';

# has 'accents_off' => ( is => 'rw' );
has 'lemma2type' => ( is => 'rw', isa =>'HashRef', default => sub {{}} );

my %type2lemmas = (

		   #surnames from http://xanghe.blogspot.cz/2009/11/top-50-common-vietnamese-surnames.html
		   ps => 'Nguyễn Trần Lê Phạm Huỳnh Vũ Phan Trương Hoàng Ngô Đặng Đỗ Bùi Võ Lý'
		   . ' Dương Lương Đinh Trịnh Lưu Đoàn Đào Thái Mai Văn Cao Vương Phùng Quách Tạ'
		   . ' Diệp Tôn La Thạch Thi Thanh Đàm Vong Triệu Bưu Phú Vĩnh Quang Tiều Hòa Trang Giang Lục Banh Nghiêm'

		   # and some more surnames from http://en.wikipedia.org/wiki/Vietnamese_name
		   . ' Bành Cao Châu Chu Chung Diệp Dương Đàm Đào Đinh Đoàn Giang Hà Hàn Kiều Kim La Lạc'
		   . ' Lâm Liễu Lục Lương Lưu Mã Mạch Mai Nghiêm Phó Phùng Quách Quang Quyền Tạ Thạch Thái'
		   . ' Sái Thi Thân Thảo Thủy Tiêu Tô Tôn Trang Triệu Trịnh Trương Văn Vĩnh Vương Vưu',

		   # common baby names from http://www.familiesonlinemagazine.com/baby-names/vietnamese.html
		   'pf' => 'An  Anh  Anh  Be  Bian  Bich  Binh  Cai  Cam  Canh  Cara  Chau  Chi  Dao  Diep'
		   . ' Diu  Doan vien  Dong  Ha  Hai  Han  Hang  Hanh_phuc  Hien  Hoa  Hong  Hong_yen  Hue'
		   . ' Hung  Huong  Huyen  Hyunh  Ket_nien  Kieu  Kim  Kim_cuc  Kim-ly  Lam  Lan  Lang  Lanh'
		   . ' Le  Lieu  Lien  Linh  Mai  My  Nam_ha  Ngoc  Ngoc_bich  Ngu  Nguyet  Nhu  Nhung  Nu'
		   . ' Phuong  Quy  Quyen  Sang  Suong  Tam  Tan  Tham  Thanh  Thanh_ha  Thao  Thi  Thom  Thu'
		   . ' Thuy  Tien  Trinh  Truc  Tuyen  Tuyet  Uoc  Van  Viet  Xuan  Yen  An  Anh dung  Binh  Bao'
		   . ' Bay  Cadeo  Canh  Chien  Chinh  Cuong  Dac_kien  Dao  Danh  Dat  De  Dien  Duc  Due  Dung'
		   . ' Duong  Hai  Hao  Hien  Hieu  Hoc  Huu  Hung  Huy  Huynh  Khan  Lanh  Lan  Lap  Loc  Minh'
		   . ' Nguyen  Nhat  Nien  Phuc  Phuoc  Pin  Quan  Quang  Quoc  Sang  Si  Sinh  Son  Tai  Tam  Tan'
		   . ' Teo  Thai  Than  Thang  Thanh  Thao  Thinh  Tho  Thu  Thuan  Thuc  Tin  Toai  Toan  Tong'
		   . ' Trang  Trieu  Trong_tri  Trong  Trung  Tu  Tuan  Tung  Tuyen  Van  Vien  Viet  Vuong  Xuan'

		   # middle names from http://en.wikipedia.org/wiki/Vietnamese_name
		   . ' Thị Văn Hữu Đức Thành Công Quang',
		  );


sub BUILD {
    my ($self) = @_;
    foreach my $type (keys %type2lemmas) {
        foreach my $lemma (map {_remove_accent($_)} grep {$_} split / /, $type2lemmas{$type}) {
	    $self->lemma2type->{$lemma} = $type;
        }
    }
}

sub _remove_accent {
    my ($form) = @_;
    $form =~ tr/áạảầãặệễêĩịỳýơòôõôụủùữúưĐ/aaaaaaeeeiiyyooooouuuuuuD/;
    return $form;
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $nroot = $zone->has_ntree() ? $zone->get_ntree() : $zone->create_ntree();

    foreach my $anode ($zone->get_atree) {
        if ( $anode->form =~ /^[A-ZĐ]/ and $self->lemma2type->{ucfirst(lc($anode->form))}) {
 	  my $new_nnode = $nroot->create_child(
					       ne_type => $self->lemma2type->{$anode->lemma},
					       normalized_name => ucfirst(lc($anode->form)),
					      );
	  $new_nnode->set_anodes($anode);
	}
    }
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2N::CS::RecognizeFrequentPersonalNames

=head1 DESCRIPTION

A very simple dictionary-based recognition of Vietnamese names.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
