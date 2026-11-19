const $ = selector => document.querySelector(selector);
const C = window.EXAM_CONFIG;
const S = supabase.createClient(C.supabaseUrl, C.supabaseAnonKey);

const form = $('#checkinForm');
const message = $('#attendanceMsg');

form.addEventListener('submit', async event => {
  event.preventDefault();
  message.textContent = '';
  const button = form.querySelector('button[type="submit"]');
  button.disabled = true;
  button.textContent = 'กำลังตรวจสอบ...';
  try {
    const { data, error } = await S.rpc('student_attendance_checkin', {
      p_code: $('#checkinCode').value.trim().toUpperCase(),
      p_student_code: $('#checkinStudentCode').value.trim(),
      p_student_name: $('#checkinStudentName').value.trim()
    });
    if (error) throw error;
    $('#successStudent').textContent = data.studentName || '-';
    $('#successTitle').textContent = data.title || '-';
    $('#successDate').textContent = data.sessionDate ? new Date(`${data.sessionDate}T00:00:00`).toLocaleDateString('th-TH', { dateStyle: 'long' }) : '-';
    $('#successStatus').textContent = data.status === 'late' ? 'มาสาย' : 'มาเรียน';
    $('#successStatus').className = data.status === 'late' ? 'late-text' : 'present-text';
    $('#successTime').textContent = data.checkedAt ? new Date(data.checkedAt).toLocaleTimeString('th-TH', { hour: '2-digit', minute: '2-digit' }) : '-';
    $('#attendanceFormView').hidden = true;
    $('#attendanceSuccess').hidden = false;
  } catch (error) {
    message.textContent = error.message || 'ไม่สามารถเช็คชื่อได้';
  } finally {
    button.disabled = false;
    button.textContent = 'ยืนยันเช็คชื่อ →';
  }
});

$('#checkinCode').addEventListener('input', event => {
  event.target.value = event.target.value.replace(/[^a-z0-9]/gi, '').toUpperCase().slice(0, 6);
});

$('#checkinAnother').addEventListener('click', () => {
  form.reset();
  message.textContent = '';
  $('#attendanceSuccess').hidden = true;
  $('#attendanceFormView').hidden = false;
  $('#checkinCode').focus();
});
