// ============================================
// Supabase Configuration
// ============================================
const SUPABASE_URL = 'https://dvhjswspljxbjxngetdc.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_5ojtC3p6Jt4blaXnYn_Cmw_AjxkVihX';

// Initialize Supabase
let supabase;
try {
  supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  console.log('Supabase initialized:', supabase);
} catch (err) {
  console.error('Failed to initialize Supabase:', err);
  document.getElementById('auth-error').textContent = 'خطا در اتصال به سرور';
}

// ============================================
// App State
// ============================================
const App = {
  currentUser: null,
  currentRoom: null,
  currentRoomType: null,
  peers: new Map(),
  localStream: null,
  screenStream: null,
  inVoice: false,
  currentVoiceRoom: null,
  typingTimeout: null,
  onlineUsers: new Set()
};

// ============================================
// Auth Functions
// ============================================
async function register(username, email, password, displayName) {
  console.log('Registering:', { username, email });
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        username,
        display_name: displayName || username
      }
    }
  });
  console.log('Register result:', { data, error });
  if (error) throw error;
  return data;
}

async function login(email, password) {
  console.log('Logging in:', { email });
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });
  console.log('Login result:', { data, error });
  if (error) throw error;
  return data;
}

async function logout() {
  await supabase.auth.signOut();
  App.currentUser = null;
  document.getElementById('auth-screen').style.display = 'flex';
  document.getElementById('app-screen').style.display = 'none';
}

async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;
  
  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single();
  
  return profile;
}

// ============================================
// Room Functions
// ============================================
async function getRooms() {
  const { data, error } = await supabase
    .from('rooms')
    .select('*')
    .order('created_at');
  return data || [];
}

async function createRoom(name, type) {
  const { data, error } = await supabase
    .from('rooms')
    .insert({ name, type, created_by: App.currentUser.id })
    .select()
    .single();
  if (error) throw error;
  return data;
}

// ============================================
// Message Functions
// ============================================
async function getMessages(roomId) {
  const { data, error } = await supabase
    .from('messages')
    .select('*, profiles:user_id (id, username, display_name, role)')
    .eq('room_id', roomId)
    .order('created_at', { ascending: true })
    .limit(100);
  return data || [];
}

async function sendMessage(roomId, content, type = 'text', fileUrl = null, fileName = null, fileSize = null) {
  const { data, error } = await supabase
    .from('messages')
    .insert({
      room_id: roomId,
      user_id: App.currentUser.id,
      type,
      content,
      file_url: fileUrl,
      file_name: fileName,
      file_size: fileSize
    })
    .select('*, profiles:user_id (id, username, display_name, role)')
    .single();
  if (error) throw error;
  return data;
}

// ============================================
// File Upload
// ============================================
async function uploadFile(file) {
  const fileExt = file.name.split('.').pop();
  const fileName = `${Math.random().toString(36).substring(2)}.${fileExt}`;
  
  const { data, error } = await supabase.storage
    .from('uploads')
    .upload(fileName, file);
  
  if (error) throw error;
  
  const { data: { publicUrl } } = supabase.storage
    .from('uploads')
    .getPublicUrl(fileName);
  
  return {
    url: publicUrl,
    name: file.name,
    size: file.size
  };
}

// ============================================
// Realtime Subscriptions
// ============================================
function subscribeToMessages(roomId) {
  return supabase
    .channel(`messages:${roomId}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'messages',
      filter: `room_id=eq.${roomId}`
    }, async (payload) => {
      const { data } = await supabase
        .from('messages')
        .select('*, profiles:user_id (id, username, display_name, role)')
        .eq('id', payload.new.id)
        .single();
      
      if (data) {
        appendMessage(data);
        scrollToBottom();
      }
    })
    .subscribe();
}

// ============================================
// UI Functions
// ============================================
function updateUserInfo() {
  if (!App.currentUser) return;
  document.getElementById('sidebar-username').textContent = App.currentUser.display_name || App.currentUser.username;
  document.getElementById('user-avatar').textContent = (App.currentUser.display_name || App.currentUser.username).charAt(0).toUpperCase();
  const roleEl = document.getElementById('sidebar-role');
  roleEl.textContent = App.currentUser.role === 'owner' ? 'مالک' : App.currentUser.role === 'admin' ? 'ادمین' : 'کاربر';
  roleEl.className = `role-badge ${App.currentUser.role}`;
}

async function renderRooms() {
  const rooms = await getRooms();
  const textList = document.getElementById('text-rooms-list');
  const voiceList = document.getElementById('voice-rooms-list');
  textList.innerHTML = '';
  voiceList.innerHTML = '';

  rooms.forEach(room => {
    const li = document.createElement('li');
    li.dataset.id = room.id;
    li.dataset.type = room.type;
    li.innerHTML = `
      <span class="room-icon">${room.type === 'voice' ? '🔊' : '💬'}</span>
      <span class="room-name">${room.name}</span>
    `;
    li.addEventListener('click', () => joinRoomUI(room.id, room.name, room.type));
    if (room.type === 'voice') voiceList.appendChild(li);
    else textList.appendChild(li);
  });

  const isAdmin = ['owner', 'admin'].includes(App.currentUser?.role);
  document.getElementById('add-text-room').style.display = isAdmin ? 'block' : 'none';
  document.getElementById('add-voice-room').style.display = isAdmin ? 'block' : 'none';
}

async function joinRoomUI(roomId, roomName, roomType) {
  App.currentRoom = roomId;
  App.currentRoomType = roomType;

  document.getElementById('welcome-screen').style.display = 'none';
  document.getElementById('chat-screen').style.display = 'flex';
  document.getElementById('chat-screen').style.flexDirection = 'column';
  document.getElementById('chat-screen').style.flex = '1';
  document.getElementById('current-room-name').textContent = roomName;

  const typeBadge = document.getElementById('current-room-type');
  typeBadge.textContent = roomType === 'voice' ? 'صوتی' : 'متنی';
  typeBadge.className = `room-type-badge ${roomType === 'voice' ? 'voice' : ''}`;

  document.getElementById('voice-channel-controls').style.display = roomType === 'voice' ? 'flex' : 'none';
  document.getElementById('message-input-area').style.display = roomType === 'text' ? 'flex' : 'none';

  document.querySelectorAll('.room-list li').forEach(li => li.classList.remove('active'));
  document.querySelector(`.room-list li[data-id="${roomId}"]`)?.classList.add('active');

  if (roomType === 'text') {
    await loadMessages(roomId);
    document.getElementById('message-input').focus();
  }

  subscribeToMessages(roomId);
}

async function loadMessages(roomId) {
  const messages = await getMessages(roomId);
  const container = document.getElementById('messages-container');
  container.innerHTML = '';
  messages.forEach(msg => appendMessage(msg));
  scrollToBottom();
}

function appendMessage(msg) {
  const container = document.getElementById('messages-container');
  const isOwn = msg.user_id === App.currentUser.id;
  const user = msg.profiles;
  const roleClass = user?.role || 'user';
  const roleName = user?.role === 'owner' ? 'مالک' : user?.role === 'admin' ? 'ادمین' : '';

  let contentHtml = '';
  if (msg.type === 'text') {
    contentHtml = `<div class="message-text">${escapeHtml(msg.content)}</div>`;
  } else if (msg.type === 'image') {
    contentHtml = `<img src="${msg.file_url}" class="message-image" alt="image">`;
  } else if (msg.type === 'voice') {
    contentHtml = `<audio controls class="message-audio" src="${msg.file_url}"></audio>`;
  } else if (msg.type === 'file') {
    const size = msg.file_size ? ` (${formatSize(msg.file_size)})` : '';
    contentHtml = `<a href="${msg.file_url}" class="message-file" target="_blank">📎 ${msg.file_name || 'فایل'}${size}</a>`;
  }

  const time = new Date(msg.created_at).toLocaleTimeString('fa-IR', { hour: '2-digit', minute: '2-digit' });

  const div = document.createElement('div');
  div.className = `message ${isOwn ? 'own' : ''}`;
  div.innerHTML = `
    <div class="message-avatar">${(user?.display_name || user?.username || '?').charAt(0).toUpperCase()}</div>
    <div class="message-content">
      <div class="message-header">
        <span class="message-username">${user?.display_name || user?.username || 'ناشناس'}</span>
        ${roleName ? `<span class="message-role role-badge ${roleClass}">${roleName}</span>` : ''}
        <span class="message-time">${time}</span>
      </div>
      ${contentHtml}
    </div>
  `;
  container.appendChild(div);
}

function scrollToBottom() {
  const container = document.getElementById('messages-container');
  container.scrollTop = container.scrollHeight;
}

function updateOnlineUsersList() {
  const list = document.getElementById('online-users-list');
  list.innerHTML = '';
  App.onlineUsers.forEach(userId => {
    const li = document.createElement('li');
    li.innerHTML = `<span class="online-dot"></span><span>${userId.substring(0, 8)}...</span>`;
    list.appendChild(li);
  });
}

// ============================================
// Voice & Screen Sharing
// ============================================
async function joinVoice() {
  if (!App.currentRoom || App.currentRoomType !== 'voice') return;
  try {
    App.localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    App.inVoice = true;
    App.currentVoiceRoom = App.currentRoom;
    document.getElementById('join-voice-btn').style.display = 'none';
    document.getElementById('leave-voice-btn').style.display = 'inline-block';
    document.getElementById('share-screen-btn').style.display = 'inline-block';
    document.getElementById('media-panel').style.display = 'block';
    document.getElementById('media-title').textContent = 'تماس صوتی';
  } catch (err) {
    console.error('Failed to get microphone:', err);
    alert('دسترسی به میکروفون رد شد');
  }
}

function leaveVoice() {
  cleanupMedia();
  App.inVoice = false;
  App.currentVoiceRoom = null;
  document.getElementById('join-voice-btn').style.display = 'inline-block';
  document.getElementById('leave-voice-btn').style.display = 'none';
  document.getElementById('share-screen-btn').style.display = 'none';
  document.getElementById('media-panel').style.display = 'none';
}

async function shareScreen() {
  try {
    App.screenStream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: true });
    document.getElementById('remote-video').srcObject = App.screenStream;
    App.screenStream.getVideoTracks()[0].onended = () => stopScreenShare();
  } catch (err) {
    console.error('Failed to share screen:', err);
  }
}

function stopScreenShare() {
  if (App.screenStream) {
    App.screenStream.getTracks().forEach(t => t.stop());
    App.screenStream = null;
  }
}

function toggleMute() {
  if (App.localStream) {
    const audioTrack = App.localStream.getAudioTracks()[0];
    if (audioTrack) {
      audioTrack.enabled = !audioTrack.enabled;
      document.getElementById('mute-btn').textContent = audioTrack.enabled ? '🎤' : '🔇';
    }
  }
}

function endCall() {
  leaveVoice();
}

function cleanupMedia() {
  App.peers.forEach(pc => pc.close());
  App.peers.clear();
  if (App.localStream) {
    App.localStream.getTracks().forEach(t => t.stop());
    App.localStream = null;
  }
  stopScreenShare();
  document.getElementById('remote-video').srcObject = null;
}

// ============================================
// Helpers
// ============================================
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function formatSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}

// ============================================
// Event Listeners
// ============================================
document.addEventListener('DOMContentLoaded', () => {
  console.log('DOM loaded');
  
  // Auth tabs
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      console.log('Tab clicked:', btn.dataset.tab);
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const tab = btn.dataset.tab;
      document.getElementById('login-form').style.display = tab === 'login' ? 'flex' : 'none';
      document.getElementById('register-form').style.display = tab === 'register' ? 'flex' : 'none';
      document.getElementById('auth-error').textContent = '';
    });
  });

  // Login
  document.getElementById('login-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    console.log('Login form submitted');
    try {
      const email = document.getElementById('login-email').value;
      const password = document.getElementById('login-password').value;
      await login(email, password);
      App.currentUser = await getCurrentUser();
      if (App.currentUser) {
        document.getElementById('auth-screen').style.display = 'none';
        document.getElementById('app-screen').style.display = 'flex';
        updateUserInfo();
        renderRooms();
      }
    } catch (err) {
      console.error('Login error:', err);
      document.getElementById('auth-error').textContent = err.message;
    }
  });

  // Register
  document.getElementById('register-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    console.log('Register form submitted');
    try {
      const username = document.getElementById('reg-username').value;
      const email = document.getElementById('reg-email').value;
      const password = document.getElementById('reg-password').value;
      const displayName = document.getElementById('reg-displayname').value;
      await register(username, email, password, displayName);
      document.getElementById('auth-error').textContent = 'ثبت نام انجام شد! ایمیل تأییدیه رو چک کنید.';
      document.getElementById('auth-error').style.color = '#2ecc71';
    } catch (err) {
      console.error('Register error:', err);
      document.getElementById('auth-error').textContent = err.message;
      document.getElementById('auth-error').style.color = '#e74c3c';
    }
  });

  // Logout
  document.getElementById('logout-btn').addEventListener('click', logout);

  // Send message
  document.getElementById('send-btn').addEventListener('click', async () => {
    const input = document.getElementById('message-input');
    const content = input.value.trim();
    if (!content || !App.currentRoom) return;
    await sendMessage(App.currentRoom, content);
    input.value = '';
  });

  document.getElementById('message-input').addEventListener('keydown', async (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      document.getElementById('send-btn').click();
    }
  });

  // File upload
  document.getElementById('upload-btn').addEventListener('click', () => {
    document.getElementById('file-input').click();
  });

  document.getElementById('file-input').addEventListener('change', async (e) => {
    if (e.target.files[0]) {
      const file = e.target.files[0];
      const uploaded = await uploadFile(file);
      let type = 'file';
      if (file.type.startsWith('image/')) type = 'image';
      else if (file.type.startsWith('audio/')) type = 'voice';
      await sendMessage(App.currentRoom, file.name, type, uploaded.url, uploaded.name, uploaded.size);
    }
  });

  // Room creation
  document.getElementById('add-text-room').addEventListener('click', () => {
    document.getElementById('new-room-type').value = 'text';
    document.getElementById('create-room-modal').style.display = 'flex';
  });

  document.getElementById('add-voice-room').addEventListener('click', () => {
    document.getElementById('new-room-type').value = 'voice';
    document.getElementById('create-room-modal').style.display = 'flex';
  });

  document.getElementById('confirm-create-room').addEventListener('click', async () => {
    const name = document.getElementById('new-room-name').value.trim();
    const type = document.getElementById('new-room-type').value;
    if (name) {
      await createRoom(name, type);
      document.getElementById('create-room-modal').style.display = 'none';
      document.getElementById('new-room-name').value = '';
      renderRooms();
    }
  });

  document.getElementById('cancel-create-room').addEventListener('click', () => {
    document.getElementById('create-room-modal').style.display = 'none';
  });

  // Voice controls
  document.getElementById('join-voice-btn').addEventListener('click', joinVoice);
  document.getElementById('leave-voice-btn').addEventListener('click', leaveVoice);
  document.getElementById('share-screen-btn').addEventListener('click', shareScreen);
  document.getElementById('mute-btn').addEventListener('click', toggleMute);
  document.getElementById('end-call-btn').addEventListener('click', endCall);
  document.getElementById('close-media-btn').addEventListener('click', endCall);

  // Check if user is already logged in
  getCurrentUser().then(user => {
    if (user) {
      App.currentUser = user;
      document.getElementById('auth-screen').style.display = 'none';
      document.getElementById('app-screen').style.display = 'flex';
      updateUserInfo();
      renderRooms();
    }
  });
});
